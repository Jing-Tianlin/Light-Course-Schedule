import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/jw_config.dart';
import '../services/jw_api_service.dart';
import '../utils/app_theme.dart';
import 'jw_import_preview_screen.dart';

/// 融合门户 WebView 导入页。
///
/// 流程：
/// 1. 打开 CAS 统一登录页，用户手动输入账号/密码/验证码；
/// 2. 登录后进入融合门户，再手动点开教务系统课表页面；
/// 3. 点击「一键导入」，App 从 WebView 中读取 EAMS 会话 Cookie 并抓取课表。
class JwWebImportScreen extends StatefulWidget {
  const JwWebImportScreen({super.key});

  @override
  State<JwWebImportScreen> createState() => _JwWebImportScreenState();
}

class _JwWebImportScreenState extends State<JwWebImportScreen> {
  final _studentIdController = TextEditingController();
  late final WebViewController _controller;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Safari/537.36',
      )
      ..enableZoom(true)
      ..setBackgroundColor(Colors.white)
      ..loadRequest(Uri.parse(JwConfig.casLoginUrl));
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _importFromWebView() async {
    final studentId = _studentIdController.text.trim();
    if (studentId.isEmpty) {
      _showMessage('请先填写学号');
      return;
    }

    setState(() => _importing = true);
    try {
      final cookies = await WebViewCookieManager().getCookies(
        domain: Uri.parse('https://eams.cupk.edu.cn'),
      );
      if (cookies.isEmpty) {
        throw Exception('未获取到教务系统登录状态，请先打开课表页面');
      }

      final cookieMap = <String, String>{
        for (final c in cookies) c.name: c.value,
      };
      JwApiService.instance.setSessionCookies(cookieMap);

      final courses = await JwApiService.instance.fetchTimetable(
        studentId: studentId,
      );
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JwImportPreviewScreen(
            courses: courses,
            semester: '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('融合门户导入'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _studentIdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '学号',
                        hintText: '用于抓取课表',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _importing ? null : _importFromWebView,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brand,
                    ),
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: const Text('一键导入'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '请在下方登录融合门户，并手动打开教务系统课表页面',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
