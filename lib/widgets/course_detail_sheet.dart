import 'package:flutter/material.dart';

import '../data/kebiao_data.dart';
import '../models/course.dart';
import '../utils/app_theme.dart';

/// 课程详情半屏模态框（Bottom Sheet）
class CourseDetailSheet extends StatelessWidget {
  final Course course;

  const CourseDetailSheet({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorOf(course);
    final maxWeek = KebiaoData.instance.maxWeek;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 课程名
            Text(
              course.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.3,
              ),
            ),
            if (course.code.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  course.code,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _row(Icons.access_time, '时间', _timeLine()),
            if (course.locSummary().isNotEmpty)
              _row(Icons.location_on_outlined, '地点', course.locSummary()),
            if (course.teacher.isNotEmpty) _row(Icons.person_outline, '教师', course.teacher),
            _row(Icons.calendar_month_outlined, '周次', course.weeksText(maxWeek)),
            if (course.type.label.isNotEmpty)
              _row(Icons.category_outlined, '类型',
                  '${course.type.label} · 第${course.start}-${course.end}节'),
            if (course.classes.isNotEmpty)
              _row(Icons.groups_outlined, '班级', course.classes.join('，')),
          ],
        ),
      ),
    );

  }

  String _timeLine() {
    final secs = KebiaoData.instance.sections;
    String? timeOf(int no) {
      for (final s in secs) {
        if (s.no == no) return s.time;
      }
      return null;
    }
    final s = timeOf(course.start);
    final e = endOf(course.end);
    return s == null ? '第${course.start}节起' : '$s - ${e ?? ''}';
  }

  String? endOf(int no) {
    for (final s in KebiaoData.instance.sections) {
      if (s.no == no) return s.endTime;
    }
    return null;
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                  fontFamily: 'PingFang SC'),
            ),
          ),
        ],
      ),
    );
  }
}