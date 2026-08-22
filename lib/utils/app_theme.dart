import 'package:flutter/material.dart';

import '../models/course.dart';

/// 全局主题与课程配色
class AppTheme {
  // 品牌色
  static const Color brand = Color(0xFF3B82F6);
  static const Color brandDark = Color(0xFF1D4ED8);

  // 一整套柔和区分色（按课程名稳定分配，保证同一门课同色）
  static const List<Color> coursePalette = [
    Color(0xFF3B82F6), // 蓝
    Color(0xFF10B981), // 绿
    Color(0xFFF59E0B), // 橙
    Color(0xFF8B5CF6), // 紫
    Color(0xFFEF4444), // 红
    Color(0xFF14B8A6), // 青
    Color(0xFFF97316), // 橘
    Color(0xFFEC4899), // 粉
    Color(0xFF0EA5E9), // 天蓝
    Color(0xFF84CC16), // 黄绿
    Color(0xFF6366F1), // 靛
    Color(0xFFA855F7), // 亮紫
  ];

  static Color colorOf(Course c) => colorForName(c.name);

  /// 课程名 → 稳定颜色（hash）
  static Color colorForName(String name) {
    if (name.isEmpty) return coursePalette.first;
    var h = 0;
    final codeUnits = name.codeUnits;
    for (var i = 0; i < codeUnits.length; i++) {
      h = (h * 31 + codeUnits[i]) & 0x7fffffff;
    }
    return coursePalette[h % coursePalette.length];
  }
}