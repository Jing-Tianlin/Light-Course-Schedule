import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/jw_course.dart';
import '../utils/jw_web_scripts.dart';
import 'jw_exception.dart';
import 'jw_parser.dart';

/// WebView 导入页的后台逻辑封装。
///
/// 职责：
/// - 维护网络日志（带上限）。
/// - 页面加载完成后注入 UA、viewport、提取学号。
/// - 从页面或网络日志中识别学期 ID。
/// - 通过同步 XHR 复用页面登录态拉取课表 JSON。
/// - 解析并返回 [JwCourse] 列表。
class JwWebImportService {
  JwWebImportService(this._controller);

  final InAppWebViewController? _controller;
  final List<String> _networkLogs = [];
  static const int _maxLogs = 500;

  /// 最近一次从页面或 JSON 中提取到的学号。
  String? studentId;

  /// 记录一条网络日志；超过上限时淘汰最旧的一条。
  void addNetworkLog(String line) {
    if (_networkLogs.length >= _maxLogs) {
      _networkLogs.removeAt(0);
    }
    _networkLogs.add(line);
    debugPrint(line);
  }

  /// 获取当前所有网络日志的不可变副本。
  List<String> get networkLogs => List.unmodifiable(_networkLogs);

  /// 页面加载完成后调用：注入 UA 覆盖、适配 viewport、尝试提取学号。
  Future<void> onPageFinished() async {
    await _evaluateSilently(JwWebScripts.userAgentOverride);
    await _evaluateSilently(JwWebScripts.fitViewport);
    await _extractStudentIdFromPage();
  }

  /// 适配屏幕（手动触发）。
  Future<void> fitViewport() async {
    await _evaluateSilently(JwWebScripts.fitViewport);
  }

  /// 拉取并解析完整课表。
  Future<List<JwCourse>> fetchCourses() async {
    final semesterId = await extractSemesterId();
    if (semesterId == null || semesterId.isEmpty) {
      throw const JwException('未能识别学期 ID，请确认课表页面已加载');
    }
    final rawJson = await fetchPrintDataJson(semesterId);
    _extractStudentIdFromJson(rawJson);

    final decoded = jsonDecode(rawJson);
    final courses = JwCourseParser.parseEams5CourseTable(decoded);
    if (courses.isEmpty) {
      throw const JwException('未解析到任何课程');
    }
    return courses;
  }

  /// 优先从页面 DOM 读取学期 ID，读取失败再从网络日志里反查。
  Future<String?> extractSemesterId() async {
    final fromPage = await _extractSemesterIdFromPage();
    if (fromPage != null && fromPage.isNotEmpty) return fromPage;
    return _extractSemesterIdFromNetworkLogs();
  }

  /// 通过同步 XHR 请求新教务 `print-data` 接口。
  Future<String> fetchPrintDataJson(String semesterId) async {
    final controller = _controller;
    if (controller == null) {
      throw const JwException('WebView 未初始化');
    }
    final js = JwWebScripts.fetchPrintData(semesterId);
    final future = controller.evaluateJavascript(source: js);
    final result = await Future.any<dynamic>([
      future,
      Future.delayed(const Duration(seconds: 15), () {
        throw const JwException('获取课表数据超时（15秒）');
      }),
    ]);
    if (result == null) {
      throw const JwException('页面返回的课表数据为空');
    }
    final text = result.toString();
    if (text.trim().isEmpty || text.trim() == '{}') {
      throw const JwException('页面返回的课表数据为空');
    }
    return text;
  }

  /// 复制当前页面 HTML。
  Future<String?> fetchPageHtml() async {
    final controller = _controller;
    if (controller == null) return null;
    final result = await controller.evaluateJavascript(
      source: JwWebScripts.pageHtml,
    );
    return result?.toString();
  }

  /// 将网络日志拼接成一个字符串。
  String formatNetworkLogs() {
    if (_networkLogs.isEmpty) return '暂无网络日志';
    return _networkLogs.join('\n---\n');
  }

  Future<String?> _extractStudentIdFromPage() async {
    final result = await _evaluateSilently(JwWebScripts.extractStudentId);
    if (result is String && result.isNotEmpty) {
      studentId = result.replaceAll('"', '').trim();
      return studentId;
    }
    return null;
  }

  Future<String?> _extractSemesterIdFromPage() async {
    final result = await _evaluateSilently(JwWebScripts.extractSemesterId);
    if (result is String && result.trim().isNotEmpty) {
      return result.trim();
    }
    return null;
  }

  String? _extractSemesterIdFromNetworkLogs() {
    final semesterRegex = RegExp(r'[?&]semesterId=(\d+)');
    final pathRegex = RegExp(r'/semester/(\d+)/print-data');
    for (final line in _networkLogs.reversed) {
      final match = semesterRegex.firstMatch(line) ??
          pathRegex.firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }

  void _extractStudentIdFromJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      final vms = decoded['studentTableVms'];
      if (vms is List && vms.isNotEmpty) {
        final first = vms.first;
        if (first is Map) {
          final code = first['code']?.toString();
          if (code != null && code.isNotEmpty) {
            studentId = code;
          }
        }
      }
    } catch (_) {
      // ignore
    }
  }

  Future<dynamic> _evaluateSilently(String source) async {
    final controller = _controller;
    if (controller == null) return null;
    try {
      return await controller.evaluateJavascript(source: source);
    } catch (_) {
      return null;
    }
  }
}
