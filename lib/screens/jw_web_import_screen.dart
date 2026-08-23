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
/// 3. 点击「一键导入」，App 自动从页面识别学号、读取 EAMS Cookie 并抓取课表。
class JwWebImportScreen extends StatefulWidget {
  const JwWebImportScreen({super.key});

  @override
  State<JwWebImportScreen> createState() => _JwWebImportScreenState();
}

class _JwWebImportScreenState extends State<JwWebImportScreen> {
  late final WebViewController _controller;
  bool _importing = false;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _fitViewport();
            _autoExtractStudentId();
          },
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

  /// 将桌面版页面的 viewport 调整为桌面宽度，并根据设备宽度动态缩放。
  Future<void> _fitViewport() async {
    try {
      await _controller.runJavaScript(
        '''
        (function() {
          var targetW = 1200;
          var vw = Math.max(
            document.documentElement.clientWidth || 1,
            window.innerWidth || 1
          );
          var scale = vw / targetW;
          var meta = document.querySelector('meta[name=viewport]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
          }
          meta.content = 'width=' + targetW + ', initial-scale=' + scale + ', maximum-scale=5, user-scalable=yes';
        })();
        ''',
      );
    } catch (_) {
      // ignore
    }
  }
  void dispose() {
    super.dispose();
  }

  /// 尝试从页面文本中自动识别学号，例如：`井天林(2024015798)`。
  Future<void> _autoExtractStudentId() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        '''
        (function() {
          var text = document.body ? document.body.innerText : '';
          var m = text.match(/[（(](\\d{10,15})[)）]/);
          if (m) return m[1];
          m = text.match(/\\b\\d{10,15}\\b/);
          return m ? m[1] : '';
        })();
        ''',
      );
      if (result is String && result.isNotEmpty) {
        _studentId = result.replaceAll('"', '').trim();
      }
    } catch (_) {
      // 页面还在加载或跨域时忽略，导入时再重试
    }
  }

  Future<String?> _getStudentIdFromPage() async {
    if (_studentId != null && _studentId!.isNotEmpty) return _studentId;
    await _autoExtractStudentId();
    if (_studentId != null && _studentId!.isNotEmpty) return _studentId;
    return null;
  }

  Future<void> _importFromWebView() async {
    final studentId = await _getStudentIdFromPage();
    if (studentId == null || studentId.isEmpty) {
      _showMessage('未能自动识别学号，请确认已打开课表页面后重试');
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
        actions: [
          TextButton(
            onPressed: () {
              _fitViewport();
              _showMessage('已尝试适配屏幕');
            },
            child: const Text(
              '适应屏幕',
              style: TextStyle(color: AppTheme.brand, fontSize: 13),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '请登录融合门户，并打开教务系统课表页面，然后点击右下角「一键导入」',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _importFromWebView,
        backgroundColor: AppTheme.brand,
        foregroundColor: Colors.white,
        icon: _importing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download),
        label: const Text('一键导入'),
      ),
    );
  }
}
