import 'package:flutter/material.dart';

import '../data/kebiao_data.dart';
import '../models/jw_course.dart';
import '../utils/app_theme.dart';

/// 教务系统课表预览页。
class JwImportPreviewScreen extends StatefulWidget {
  final List<JwCourse> courses;
  final String semester;

  const JwImportPreviewScreen({
    super.key,
    required this.courses,
    required this.semester,
  });

  @override
  State<JwImportPreviewScreen> createState() => _JwImportPreviewScreenState();
}

class _JwImportPreviewScreenState extends State<JwImportPreviewScreen> {
  late final List<JwCourse> _courses;
  late final List<JwCourse> _removed;

  @override
  void initState() {
    super.initState();
    _courses = List.of(widget.courses);
    _removed = [];
  }

  /// 判断两个课程是否在同一周有重叠。
  bool _haveWeekOverlap(List<int> a, List<int> b) {
    final setA = a.toSet();
    return b.any(setA.contains);
  }

  List<List<JwCourse>> _findConflicts() {
    final conflicts = <List<JwCourse>>[];
    for (var i = 0; i < _courses.length; i++) {
      for (var j = i + 1; j < _courses.length; j++) {
        final a = _courses[i];
        final b = _courses[j];
        // 同一门课的不同时间段不视为冲突。
        if (a.courseCode.isNotEmpty &&
            a.courseCode == b.courseCode) {
          continue;
        }
        if (a.dayOfWeek != b.dayOfWeek) continue;
        if (a.startSection > b.endSection ||
            b.startSection > a.endSection) {
          continue;
        }
        // 只有周次也重叠才算真正冲突。
        if (!_haveWeekOverlap(a.weeks, b.weeks)) continue;
        conflicts.add([a, b]);
      }
    }
    return conflicts;
  }

  /// 按课程代码/名称去重后的课程门数。
  int _uniqueCourseCount() {
    final keys = <String>{};
    for (final c in _courses) {
      keys.add(c.courseCode.isNotEmpty ? c.courseCode : c.name);
    }
    return keys.length;
  }

  void _removeCourse(JwCourse course) {
    setState(() {
      _courses.remove(course);
      _removed.add(course);
    });
  }

  Future<void> _confirmImport() async {
    final converted = _courses.map((c) => c.toCourse()).toList();
    await KebiaoData.instance.setCourses(converted);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入 ${converted.length} 门课程')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = _findConflicts();
    final weeks = <int>{};
    for (final c in _courses) {
      weeks.addAll(c.weeks);
    }
    final weekText = weeks.isEmpty
        ? '无'
        : '${weeks.reduce((a, b) => a < b ? a : b)}-${weeks.reduce((a, b) => a > b ? a : b)}周';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('课表预览'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _stat('课程门数', '${_uniqueCourseCount()}'),
                const SizedBox(width: 12),
                _stat('上课次数', '${_courses.length}'),
                const SizedBox(width: 12),
                _stat('冲突', '${conflicts.length}'),
              ],
            ),
          ),
          if (conflicts.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '检测到 ${conflicts.length} 处时间冲突，请手动处理',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                final c = _courses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '周${c.dayOfWeek} 第${c.startSection}-${c.endSection}节\n'
                      '${c.teacher} · ${c.classroom}\n'
                      '${c.weeks.isEmpty ? "无周次" : c.weeks.join(",")}周',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeCourse(c),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _courses.isEmpty ? null : _confirmImport,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brand,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.check),
            label: Text('确认导入（${_uniqueCourseCount()} 门，${_courses.length} 次）'),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
