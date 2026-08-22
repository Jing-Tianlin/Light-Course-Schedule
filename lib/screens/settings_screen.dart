import 'package:flutter/material.dart';

import '../data/kebiao_data.dart';
import '../utils/app_theme.dart';
import '../utils/schedule_utils.dart';
import 'edit_schedule_screen.dart';

/// 设置页：学期名称、开学日期、最大周数
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _termC;
  final TextEditingController _dateC = TextEditingController();
  final TextEditingController _maxWeekC = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = KebiaoData.instance;
    _termC = TextEditingController(text: d.termName);
    _dateC.text =
        '${d.termStart.year}-${d.termStart.month.toString().padLeft(2, '0')}-${d.termStart.day.toString().padLeft(2, '0')}';
    _maxWeekC.text = '${d.maxWeek}';
  }

  @override
  void dispose() {
    _termC.dispose();
    _dateC.dispose();
    _maxWeekC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            children: [
              _field(_termC, '学期名称', '如：2026-2027 秋季学期'),
              const Divider(height: 1),
              _field(_dateC, '开学日期（周一）', '格式：YYYY-MM-DD'),
              const Divider(height: 1),
              _field(_maxWeekC, '学期总周数', '如：17'),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: const Icon(Icons.schedule, color: AppTheme.brand),
              title: const Text('作息时间'),
              subtitle: const Text('设置各节次的开始与结束时间'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EditScheduleScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brand,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('保存设置'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _clearCourses,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade200),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('清空课表'),
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: c,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          border: InputBorder.none,
        ),
      ),
    );
  }

  void _save() {
    final d = KebiaoData.instance;
    final name = _termC.text.trim();
    if (name.isNotEmpty) d.setTermName(name);

    final parts = _dateC.text.trim().split('-');
    DateTime? start;
    var y = 0, m = 0, day = 0;
    if (parts.length == 3) {
      y = int.tryParse(parts[0]) ?? 0;
      m = int.tryParse(parts[1]) ?? 0;
      day = int.tryParse(parts[2]) ?? 0;
      start = DateTime(y, m, day);
    }
    if (start == null || start.year != y || start.month != m || start.day != day) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开学日期格式应为 YYYY-MM-DD')),
      );
      return;
    }

    final monday = ScheduleUtils.mondayOf(start);
    d.setTermStart(monday);
    _dateC.text = _fmtDate(monday);

    final mw = int.tryParse(_maxWeekC.text.trim());
    if (mw == null || mw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('学期总周数应为正整数')),
      );
      return;
    }
    d.setMaxWeek(mw);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _clearCourses() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空课表'),
        content: const Text('确定要删除当前所有导入的课程吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await KebiaoData.instance.clearCourses();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('课表已清空')),
    );
  }
}
