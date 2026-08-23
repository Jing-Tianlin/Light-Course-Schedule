import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/jw_config.dart';
import '../services/jw_api_service.dart';
import '../utils/app_theme.dart';
import 'jw_import_preview_screen.dart';

/// 教务系统登录页。
class JwLoginScreen extends StatefulWidget {
  const JwLoginScreen({super.key});

  @override
  State<JwLoginScreen> createState() => _JwLoginScreenState();
}

class _JwLoginScreenState extends State<JwLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _loading = false;
  bool _portalMode = true;
  bool _formMode = false;
  Uint8List? _captchaBytes;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    try {
      final bytes = await JwApiService.instance.fetchCaptcha();
      if (!mounted) return;
      setState(() => _captchaBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '验证码获取失败，请重试');
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorText = '请输入学号和密码');
      return;
    }
    if (_formMode && _captchaBytes != null && _captchaController.text.trim().isEmpty) {
      setState(() => _errorText = '请输入验证码');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      String token;
      if (_portalMode) {
        token = await JwApiService.instance.loginWithPortal(
          username: username,
          password: password,
        );
      } else if (_formMode) {
        token = await JwApiService.instance.loginWithForm(
          username: username,
          password: password,
          captcha: _captchaController.text.trim(),
        );
      } else {
        token = await JwApiService.instance.loginWithApi(
          username: username,
          password: password,
        );
      }

      // 获取当前学期信息（失败不阻塞，可手动选择）
      String? semester;
      try {
        final time = await JwApiService.instance.fetchCurrentTime();
        semester = time['xnxqh']?.toString() ?? time['xnxqid']?.toString();
      } catch (_) {
        // ignore
      }

      final courses = await JwApiService.instance.fetchTimetable(
        token: token,
        studentId: username,
        semester: semester,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JwImportPreviewScreen(
            courses: courses,
            semester: semester ?? '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('教务系统导入'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '中石大克校区新教务系统',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              JwConfig.baseUrl,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '学号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
              Row(
                children: [
                  const Text('使用融合门户登录'),
                  Switch(
                    value: _portalMode,
                    onChanged: (v) {
                      setState(() {
                        _portalMode = v;
                        _errorText = null;
                        if (!v && _formMode) _loadCaptcha();
                      });
                    },
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('使用表单模式'),
                Switch(
                  value: _formMode,
                  onChanged: (v) {
                    setState(() {
                      _formMode = v;
                      _errorText = null;
                      if (v) _loadCaptcha();
                    });
                  },
                ),
              ],
            ),
            if (_formMode) ...[
              if (_captchaBytes != null)
                Container(
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.memory(_captchaBytes!, fit: BoxFit.contain),
                ),
              TextField(
                controller: _captchaController,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: TextStyle(color: Colors.red.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _login,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brand,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('登录并获取课表'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : _loadCaptcha,
              child: const Text('刷新验证码'),
            ),
          ],
        ),
      ),
    );
  }
}
