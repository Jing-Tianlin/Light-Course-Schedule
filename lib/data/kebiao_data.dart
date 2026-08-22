import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../services/course_store.dart';
import '../utils/schedule_utils.dart';

/// 课表数据仓库（默认数据 + 节次配置）
class KebiaoData extends ChangeNotifier {
  KebiaoData._();

  static final KebiaoData instance = KebiaoData._();

  String termName = '2026-2027 秋季学期';
  int maxWeek = 17;

  /// 开学首周周一
  DateTime termStart = DateTime(2026, 8, 17);

  /// 节次时间段
  List<Section> sections = const [
    Section(1, '上午', '08:00'),
    Section(2, '上午', '08:50'),
    Section(3, '上午', '09:55'),
    Section(4, '上午', '10:45'),
    Section(5, '上午', '11:35'),
    Section(6, '下午', '14:00'),
    Section(7, '下午', '14:50'),
    Section(8, '下午', '15:40'),
    Section(9, '下午', '16:30'),
    Section(10, '晚上', '19:00'),
    Section(11, '晚上', '19:50'),
    Section(12, '晚上', '20:40'),
  ];

  /// 课程列表（取自 Word 导入，持久化在本地）
  List<Course> courses = [];
  bool _loaded = false;

  /// 从本地存储加载课程与设置（App 启动时调用）
  Future<void> loadFromStorage() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await CourseStore.readCourses();
      if (p != null) courses = p;
    } catch (_) {
      /* 忽略读取错误 */
    }
    try {
      final s = await CourseStore.readSettings();
      if (s != null) _applySettings(s);
    } catch (_) {
      /* 忽略读取错误 */
    }
    notifyListeners();
  }

  /// 写入导入的课程并持久化
  Future<void> setCourses(List<Course> list) async {
    courses = list;
    notifyListeners();
    await CourseStore.writeCourses(list);
  }

  /// 清空所有课程并持久化
  Future<void> clearCourses() => setCourses(const []);

  /// 指定星期当天在指定周的课程
  List<Course> coursesOfDay(int week, int day) =>
      courses.where((c) => c.day == day && c.inWeek(week)).toList();

  // ---- 可编辑配置（保存后通知界面刷新） ----

  /// 更新某节次的开始与下课时间，time/end 形如 "08:00"
  void updateSectionTime(int no, String time, {String? end}) {
    sections = sections
        .map((s) => s.no == no
            ? Section(s.no, s.block, time, end ?? s.end)
            : s)
        .toList();
    notifyListeners();
    _persistSettings();
  }

  /// 更新学期名称
  void setTermName(String v) {
    termName = v;
    notifyListeners();
    _persistSettings();
  }

  /// 更新开学日期
  void setTermStart(DateTime d) {
    termStart = ScheduleUtils.mondayOf(d);
    notifyListeners();
    _persistSettings();
  }

  /// 更新学期总周数
  void setMaxWeek(int w) {
    maxWeek = w;
    notifyListeners();
    _persistSettings();
  }

  // ---- 设置序列化 ----

  Map<String, dynamic> _settingsToJson() => {
        'termName': termName,
        'termStart': '${termStart.year}-'
            '${termStart.month.toString().padLeft(2, '0')}-'
            '${termStart.day.toString().padLeft(2, '0')}',
        'maxWeek': maxWeek,
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  void _applySettings(Map<String, dynamic> j) {
    if (j['termName'] is String) termName = j['termName'] as String;
    if (j['maxWeek'] is int) maxWeek = j['maxWeek'] as int;
    final ts = j['termStart'] as String?;
    if (ts != null) {
      final parts = ts.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          termStart = ScheduleUtils.mondayOf(DateTime(y, m, d));
        }
      }
    }
    final secs = j['sections'] as List?;
    if (secs != null && secs.isNotEmpty) {
      sections = secs
          .map((e) => Section.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _persistSettings() async {
    try {
      await CourseStore.writeSettings(_settingsToJson());
    } catch (_) {
      /* 忽略写入错误 */
    }
  }
}