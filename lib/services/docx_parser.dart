import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/course.dart';

/// 解析结果
class DocxParseResult {
  final List<Course> courses;
  final List<String> warnings;
  const DocxParseResult(this.courses, this.warnings);
}

// ---- 顶层正则（供解析器与课程构建器共用）----
// 课程代码：不含中文、含至少一个数字、由字母/数字/点/短横组成。
// 兼容 160527C051.01 / 202420251001273 / CS101 / MATH202 等不同学校的写法。
final RegExp _codeRe = RegExp(r'^(?=.*\d)[A-Za-z0-9.\-]{4,20}$');
// 周次括号，兼容多种写法：(1~9周) / (10-17周) / (6周) / (第1~10,12周) / (9，11，12周) / (1~5,7~8周)
final RegExp _weekParenRe =
    RegExp(r'\(\s*第?\s*([\d，,、;；~—\-\s]+?)\s*周\s*\)');
// 节次，兼容范围与单节：(1-2节) / (4-5节) / (8节) / (第1-2节)
final RegExp _secRe =
    RegExp(r'\(\s*第?\s*(\d+)\s*(?:[-~—]\s*(\d+))?\s*节\s*\)');
// 教师：中文姓名 + 括号内学号，如 崔立杰(2022592116) / 丁英宏(1611) / 迪拉热·海米提(2023591201)
final RegExp _teacherRe = RegExp(
    r'([\u4e00-\u9fa5]+(?:[·•・][\u4e00-\u9fa5]+)*)\s*[（(]\s*\d{4,11}\s*[)）]');

/// 解析 Word(.docx) 中的课表表格。
///
/// 目标文档结构（典型大学课表）：
///  - 表头行：第一格为「时段+节次」合并列(span=2)，随后为 星期一~星期日。
///  - 数据行：首列为 上午/下午/晚上，次列为节次号(1-12)，随后 7 列为每天课程。
///  - 每个课程格内的段落顺序固定为：
///      课程名 → 课程代码 → (周次)(节次)地点 教师(学号) [可多行] → 班级
class DocxParser {
  // 星期别名：兼容「星期一/周一」「星期日/周日/星期天/周天」等常见写法
  static const List<List<String>> _weekNames = [
    ['星期一', '周一'],
    ['星期二', '周二'],
    ['星期三', '周三'],
    ['星期四', '周四'],
    ['星期五', '周五'],
    ['星期六', '周六'],
    ['星期日', '周日', '星期天', '周天'],
  ];

  /// 从表头文本中识别星期，返回 0=周一 .. 6=周日；未识别返回 -1
  static int _matchDay(String text) {
    for (var i = 0; i < _weekNames.length; i++) {
      for (final n in _weekNames[i]) {
        if (text.contains(n)) return i;
      }
    }
    return -1;
  }

  /// 主入口：字节流 → 课程列表
  static DocxParseResult parse(Uint8List bytes) {
    final warnings = <String>[];
    final courses = <Course>[];
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    ArchiveFile? docFile;
    for (final f in archive) {
      if (f.name == 'word/document.xml') {
        docFile = f;
        break;
      }
    }
    if (docFile == null) {
      throw FormatException('不是有效的 .docx 文件（缺少 word/document.xml）');
    }
    final xml = utf8.decode(docFile.content);
    late XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
      _iterTables(doc, courses, warnings);
    } catch (e) {
      throw FormatException('解析 docx 内容失败: $e');
    }
    return DocxParseResult(courses, warnings);
  }

  static void _iterTables(
      XmlDocument doc, List<Course> out, List<String> warnings) {
    for (final tbl in doc.rootElement.findAllElements('w:tbl')) {
      _parseTable(tbl, out, warnings);
    }
  }

  /// 解析单个表格
  static void _parseTable(
      XmlElement tbl, List<Course> out, List<String> warnings) {
    final trs = tbl.findAllElements('w:tr').toList();
    if (trs.isEmpty) return;

    // 1) 表头：建立「展开列号 → 星期下标(0=周一)」
    final colDay = <int, int>{};
    final headerCells = trs.first.findAllElements('w:tc').toList();
    var off = 0;
    for (final tc in headerCells) {
      final span = _gridSpan(tc);
      final text = _norm(cellParagraphs(tc).join(' '));
      final day = _matchDay(text);
      if (day >= 0) {
        colDay[off] = day;
      }
      off += span;
    }

    // 2) 数据行：从第 2 行开始（跳过表头）
    for (var r = 1; r < trs.length; r++) {
      final cells = trs[r].findAllElements('w:tc').toList();
      var col = 0;
      for (final tc in cells) {
        final span = _gridSpan(tc);
        // 该格覆盖的列区间内的星期（通常单列）
        final dayCols = <int>[for (var c = 0; c < span; c++) col + c];
        final day = dayCols
            .map((c) => colDay[c])
            .firstWhere((d) => d != null, orElse: () => -1)!;
        // -1 表示该列非星期列（时段/节次列），跳过
        if (day >= 0) {
          final paras = cellParagraphs(tc);
          final text = paras.join('\n').trim();
          if (text.isNotEmpty) {
            _parseCell(day, paras, out, warnings);
          }
        }
        col += span;
      }
    }
  }

  /// 拆分单格内的多门课并解析。
  ///
  /// 以「课程代码行」为课程分界；课程名出现在代码行之前，
  /// 因此用 pendingName 缓冲，待代码行出现时一并归属到当前课程。
  static void _parseCell(
      int day, List<String> paras, List<Course> out, List<String> warnings) {
    _CourseBuilder? cur;
    String? pendingName;

    for (var i = 0; i < paras.length; i++) {
      final t = paras[i].trim();
      if (t.isEmpty) continue;

      if (_codeRe.hasMatch(t)) {
        // 遇到新的课程代码：结束当前课并开启新课
        if (cur != null && cur.hasContent) cur.finish(out, warnings);
        cur = _CourseBuilder(day)
          ..code = t
          ..name = pendingName ?? '';
        pendingName = null;
      } else if (t.contains('节') && t.contains('周')) {
        // 上课安排行（含周次与节次）
        cur?.addPlacement(t, warnings);
      } else if (cur != null && cur.hasContent && !_nextNonEmptyIsCode(paras, i)) {
        // 课程已开始、且下一段不是课程代码 → 班级（含不含「班」字的专业列表）
        cur.addClasses(t);
      } else {
        // 纯文字且下一段是代码 → 课程名
        pendingName = t;
      }
    }
    if (cur != null && cur.hasContent) cur.finish(out, warnings);
  }

  /// 从 [start+1] 起找第一个非空段，判断其是否为课程代码
  static bool _nextNonEmptyIsCode(List<String> paras, int start) {
    for (var j = start + 1; j < paras.length; j++) {
      final t = paras[j].trim();
      if (t.isEmpty) continue;
      return _codeRe.hasMatch(t);
    }
    return false;
  }

  /// 单元格 gridSpan（列合并数），默认 1
  static int _gridSpan(XmlElement tc) {
    final gs = tc.findAllElements('w:gridSpan').firstOrNull;
    if (gs == null) return 1;
    return int.tryParse(gs.getAttribute('w:val') ?? '1') ?? 1;
  }

  /// 单元格文本：各段落（保留空段）
  static List<String> cellParagraphs(XmlElement tc) {
    final paras = <String>[];
    for (final p in tc.findAllElements('w:p')) {
      final t = p.findAllElements('w:t').map((n) => n.innerText).join();
      paras.add(t.trim());
    }
    return paras;
  }

  /// 归一化空白（含全角空格），用于表头匹配等
  static String _norm(String s) =>
      s.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 从安排行中提取地点：去掉周次、节次、教师(学号)
String _extractLoc(String ln) {
  var loc = ln
      .replaceAll(_weekParenRe, ' ')
      .replaceAll(_secRe, ' ')
      .replaceAll(_teacherRe, ' ')
      .replaceAll('/', ' ');
  loc = loc
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return loc;
}

/// 从周次括号内容中解析出所有周段（支持单周、多范围、中英文逗号/顿号）
List<WeekRange> _parseWeeks(String content) {
  final ranges = <WeekRange>[];
  final normalized = content
      .replaceAll('，', ',')
      .replaceAll('、', ',')
      .replaceAll('；', ',')
      .replaceAll(';', ',');
  for (final part in normalized.split(',')) {
    final seg = part.trim();
    if (seg.isEmpty) continue;
    final range = RegExp(r'^(\d+)\s*[~—\-]\s*(\d+)$').firstMatch(seg);
    if (range != null) {
      final a = int.parse(range.group(1)!);
      final b = int.parse(range.group(2)!);
      ranges.add(WeekRange(a, b));
      continue;
    }
    final single = RegExp(r'^(\d+)$').firstMatch(seg);
    if (single != null) {
      final v = int.parse(single.group(1)!);
      ranges.add(WeekRange(v, v));
    }
  }
  return ranges;
}

/// 单门课程的增量构建器
class _CourseBuilder {
  final int day;
  String name = '';
  String code = '';
  String? teacher;
  int? startSec;
  int? endSec;
  final List<Placement> placements = [];
  final List<String> classes = [];

  _CourseBuilder(this.day);

  bool get hasContent => code.isNotEmpty || placements.isNotEmpty;

  void addPlacement(String ln, List<String> warnings) {
    if (code.isEmpty) {
      // 上课信息出现在代码之前，可能是上一格残留，忽略
      return;
    }
    final wm = _weekParenRe.firstMatch(ln);
    final sm = _secRe.firstMatch(ln);
    if (wm == null || sm == null) {
      warnings.add('忽略无法识别的安排：$ln');
      return;
    }
    final weekRanges = _parseWeeks(wm.group(1)!);
    if (weekRanges.isEmpty) {
      warnings.add('忽略无法识别的安排：$ln');
      return;
    }
    final ss = int.parse(sm.group(1)!);
    // 单节（如 (8节)）时结束节等于开始节
    final se = sm.group(2) != null ? int.parse(sm.group(2)!) : ss;
    if (startSec == null) {
      startSec = ss;
      endSec = se;
    } else {
      // 多条安排取最广节次范围
      if (ss < startSec!) startSec = ss;
      if (se > endSec!) endSec = se;
    }
    final tm = _teacherRe.firstMatch(ln);
    if (tm != null) teacher = tm.group(1);
    final loc = _extractLoc(ln);
    final locText = loc.isEmpty ? code : loc;
    // 一条安排可能含多个不连续周段（如 1~10,12周），逐段生成 placement
    for (final wr in weekRanges) {
      placements.add(Placement(wr, locText));
    }
  }

  void addClasses(String ln) {
    classes.addAll(ln
        .split(RegExp(r'[,，;；]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty));
  }

  void finish(List<Course> out, List<String> warnings) {
    if (placements.isEmpty || startSec == null || endSec == null) {
      warnings.add('「${name.isEmpty ? code : name}」缺少可用的周次/节次安排');
      return;
    }
    final weeks = placements.map((p) => p.weeks).toList();
    out.add(Course(
      name: name.isEmpty ? code : name,
      code: code,
      day: day,
      start: startSec!,
      end: endSec!,
      weeks: weeks,
      loc: placements.first.loc,
      placements: placements,
      teacher: teacher ?? '',
      classes: classes,
    ));
  }
}
