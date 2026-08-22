import 'package:flutter/material.dart';

import '../data/kebiao_data.dart';
import '../utils/app_theme.dart';

/// 作息时间编辑页：手动设置各节次的开始时间
class EditScheduleScreen extends StatefulWidget {
  const EditScheduleScreen({super.key});

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  final List<TextEditingController> _starts = [];
  final List<TextEditingController> _ends = [];

  @override
  void initState() {
    super.initState();
    for (final s in KebiaoData.instance.sections) {
      _starts.add(TextEditingController(text: s.time));
      _ends.add(TextEditingController(text: s.endTime));
    }
  }

  @override
  void dispose() {
    for (final c in _starts) {
      c.dispose();
    }
    for (final c in _ends) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = KebiaoData.instance.sections;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('作息时间'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存',
                style: TextStyle(
                    color: AppTheme.brand, fontWeight: FontWeight.w700)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('节次',
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
                const Spacer(),
                Text('开始',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(width: 10),
                Text('下课',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(width: 10),
                Text('时段',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: sections.length,
        itemBuilder: (context, i) {
          final s = sections[i];
          final isNewBlock = i == 0 || s.block != sections[i - 1].block;
          return Column(
            children: [
              if (isNewBlock && i > 0)
                Container(
                  width: double.infinity,
                  color: AppTheme.brand.withValues(alpha: 0.05),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Text(
                    s.block,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.brand, fontWeight: FontWeight.w700),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text('第${s.no}节',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87)),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 74,
                      child: TextField(
                        controller: _starts[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 74,
                      child: TextField(
                        controller: _ends[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        s.block,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _save() {
    final d = KebiaoData.instance;
    for (var i = 0; i < _starts.length; i++) {
      final st = _starts[i].text.trim();
      final en = _ends[i].text.trim();
      if (!_isValidTime(st) || !_isValidTime(en)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('时间格式应为 HH:mm')),
        );
        return;
      }
      d.updateSectionTime(i + 1, st, end: en);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('作息时间已保存')),
    );
    Navigator.pop(context);
  }

  bool _isValidTime(String t) {
    final m = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$').hasMatch(t);
    return m;
  }
}