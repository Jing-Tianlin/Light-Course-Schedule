import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/kebiao_data.dart';
import '../services/docx_parser.dart';
import '../utils/app_theme.dart';
import 'jw_web_import_screen.dart';

/// 导入页：选择 Word(.docx) 并解析入库
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _picking = false;
  int? _count;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('导入课表'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📄', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('导入 Word 课表',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('支持 .docx 文件，自动解析课程安排',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              if (_count != null) ...[
                const SizedBox(height: 16),
                Text('已导入 $_count 门课程',
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.brand,
                        fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _picking ? null : _pickFile,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brand,
                  minimumSize: const Size(220, 48),
                ),
                icon: _picking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file),
                label: Text(_count == null ? '选择 Word 文件' : '重新导入'),
              ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JwWebImportScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brand,
                    side: const BorderSide(color: AppTheme.brand),
                    minimumSize: const Size(220, 48),
                  ),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('从教务系统导入'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true, // 关键：让 file.bytes 返回文件内容
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    final Uint8List? path = file.bytes;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法读取所选文件，请重试')),
      );
      return;
    }

    setState(() => _picking = true);
    try {
      final r = DocxParser.parse(path);
      await KebiaoData.instance.setCourses(r.courses);
      if (!mounted) return;
      setState(() {
        _picking = false;
        _count = r.courses.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              r.warnings.isEmpty
                  ? '导入成功：共 ${r.courses.length} 门课程'
                  : '导入成功（${r.courses.length} 门），${r.warnings.length} 条无法识别'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _picking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }
}