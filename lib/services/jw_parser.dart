import '../models/jw_course.dart';

/// 强智教务系统课表数据解析器。
///
/// 不同学校返回字段略有差异，这里兼容常见字段名：
/// - 课程名称：kcmc / courseName / name
/// - 教师：jsxm / teacher
/// - 教室：jsmc / classroom / room
/// - 星期：xqj / dayOfWeek / day
/// - 节次：ksjc / jssjc / startSection / endSection / jc
/// - 周次：kkzc / weeks / zc
class JwCourseParser {
  JwCourseParser._();

  static JwCourse fromJson(Map<String, dynamic> json, {String? semester}) {
    final name = _str(json, ['kcmc', 'courseName', 'name', 'kcm']);
    final teacher = _str(json, ['jsxm', 'teacher', 'teather']);
    final classroom = _str(json, ['jsmc', 'classroom', 'room', 'jxlmc']);
    final day = _int(json, ['xqj', 'dayOfWeek', 'day', 'xq']) ?? 1;
    final start = _int(json, ['ksjc', 'startSection', 'kssjd', 'jc']) ?? 1;
    final end = _int(json, ['jssjc', 'endSection', 'jssjd']) ?? start;
    final weeks = parseWeeks(_str(json, ['kkzc', 'weeks', 'zc', 'zcs']) ?? '');
    final rawSemester = semester ?? _str(json, ['xnxqid', 'semester', 'xqmc']);
    final id = _str(json, ['kch', 'courseId', 'id']) ?? '$name-$day-$start';

    return JwCourse(
      id: id,
      name: name,
      teacher: teacher,
      classroom: classroom,
      dayOfWeek: day,
      startSection: start,
      endSection: end,
      weeks: weeks,
      semester: rawSemester ?? '',
      rawData: json,
    );
  }

  /// 解析周次字符串。
  ///
  /// 支持格式：
  /// - 1-16
  /// - 1-8,10-16
  /// - 第1-8,10-16周
  /// - 1,3,5,7
  /// - 1-16(单周) / 1-16(双周)
  static List<int> parseWeeks(String input) {
    if (input.isEmpty) return const [];
    var text = input
        .replaceAll('第', '')
        .replaceAll('周', '')
        .replaceAll('单', '')
        .replaceAll('双', '')
        .replaceAll(' ', '');
    final result = <int>{};
    for (final part in text.split(RegExp(r'[,，;；、]'))) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final range = RegExp(r'^(\d+)\s*[-~—]\s*(\d+)$').firstMatch(p);
      if (range != null) {
        final a = int.parse(range.group(1)!);
        final b = int.parse(range.group(2)!);
        for (var w = a; w <= b; w++) {
          result.add(w);
        }
      } else {
        final single = int.tryParse(p);
        if (single != null) result.add(single);
      }
    }
    final list = result.toList()..sort();
    return list;
  }

  static String _str(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final n = int.tryParse(v.trim());
        if (n != null) return n;
      }
    }
    return null;
  }
}
