import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../config/jw_config.dart';
import '../services/jw_web_import_service.dart';
import '../utils/app_theme.dart';
import 'jw_import_preview_screen.dart';

/// 融合门户 WebView 导入页。
///
/// 流程：
/// 1. 以电脑端 UA 打开 CAS 统一登录页；
/// 2. 用户登录后进入融合门户并打开教务系统课表页面；
/// 3. 点击「一键导入」，通过 [JwWebImportService] 复用页面会话抓取课表。
class JwWebImportScreen extends StatefulWidget {
  const JwWebImportScreen({super.key});

  @override
  State<JwWebImportScreen> createState() => _JwWebImportScreenState();
}

class _JwWebImportScreenState extends State<JwWebImportScreen> {
  InAppWebViewController? _webViewController;
  JwWebImportService? _service;

  bool _importing = false;
  bool _isLoading = true;
  int _loadProgress = 0;
  String? _lastError;

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
            onPressed: _isLoading || _service == null
                ? null
                : () async {
                    await _service!.fitViewport();
                    _showMessage('已尝试适配屏幕');
                  },
            child: const Text(
              '适应屏幕',
              style: TextStyle(color: AppTheme.brand, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _importing || _isLoading ? null : _importFromWebView,
            child: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.brand,
                    ),
                  )
                : const Text(
                    '一键导入',
                    style: TextStyle(color: AppTheme.brand, fontSize: 13),
                  ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copyHtml',
                child: Text('复制页面源码'),
              ),
              const PopupMenuItem(
                value: 'copyLogs',
                child: Text('复制网络日志'),
              ),
              const PopupMenuItem(
                value: 'copyCourseJson',
                child: Text('复制课表JSON'),
              ),
            ],
            onSelected: (value) async {
              switch (value) {
                case 'copyHtml':
                  await _copyPageHtml();
                case 'copyLogs':
                  await _copyNetworkLogs();
                case 'copyCourseJson':
                  await _copyCourseTableJson();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(JwConfig.casLoginUrl),
              ),
              initialSettings: InAppWebViewSettings(
                userAgent: JwConfig.desktopUserAgent,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                cacheEnabled: false,
                clearCache: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                allowUniversalAccessFromFileURLs: true,
                useOnLoadResource: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                _service = JwWebImportService(controller);
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                  _lastError = null;
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() => _loadProgress = progress);
              },
              onLoadStop: (controller, url) async {
                await _service?.onPageFinished();
                setState(() {
                  _isLoading = false;
                  _lastError = null;
                });
              },
              onReceivedError: (controller, request, error) {
                debugPrint('WebView error: ${error.description}');
                setState(() => _lastError = error.description);
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('WebView console: ${consoleMessage.message}');
              },
              onLoadResource: (controller, resource) {
                _service?.addNetworkLog(
                  'Resource: ${resource.initiatorType} ${resource.url}',
                );
              },
            ),
            if (_isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _loadProgress / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brand),
                ),
              ),
            if (_lastError != null && !_isLoading)
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _lastError!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromWebView() async {
    final service = _service;
    if (service == null) {
      _showMessage('WebView 未初始化');
      return;
    }
    setState(() => _importing = true);
    try {
      final courses = await service.fetchCourses();
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

  Future<void> _copyPageHtml() async {
    final service = _service;
    if (service == null) {
      _showMessage('WebView 未初始化');
      return;
    }
    final html = await service.fetchPageHtml();
    if (html == null || html.isEmpty) {
      _showMessage('未能获取页面源码');
      return;
    }
    await Clipboard.setData(ClipboardData(text: html));
    _showMessage('页面源码已复制到剪贴板');
  }

  Future<void> _copyNetworkLogs() async {
    final service = _service;
    final text = service?.formatNetworkLogs() ?? '暂无网络日志';
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('网络日志已复制到剪贴板');
  }

  Future<void> _copyCourseTableJson() async {
    final service = _service;
    if (service == null) {
      _showMessage('WebView 未初始化');
      return;
    }
    setState(() => _importing = true);
    try {
      final semesterId = await service.extractSemesterId();
      if (semesterId == null || semesterId.isEmpty) {
        _showMessage('未能识别学期 ID，请确认课表页面已加载');
        return;
      }
      final rawJson = await service.fetchPrintDataJson(semesterId);
      await Clipboard.setData(ClipboardData(text: rawJson));
      _showMessage('课表 JSON 已复制到剪贴板');
    } catch (e) {
      _showMessage('复制课表 JSON 失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
