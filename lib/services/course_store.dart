import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';

/// 课程数据的本地持久化（shared_preferences）
class CourseStore {
  static const _key = 'kebiao_courses_v1';
  static const _settingsKey = 'kebiao_settings_v1';

  /// 读取课程，返回 null 表示无数据
  static Future<List<Course>?> readCourses() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Course.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 写入课程
  static Future<void> writeCourses(List<Course> courses) async {
    final sp = await SharedPreferences.getInstance();
    final raw =
        jsonEncode(courses.map((c) => c.toJson()).toList());
    await sp.setString(_key, raw);
  }

  /// 读取设置（学期/开学日期/周数/作息），返回 null 表示未保存过
  static Future<Map<String, dynamic>?> readSettings() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// 写入设置
  static Future<void> writeSettings(Map<String, dynamic> settings) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_settingsKey, jsonEncode(settings));
  }
}