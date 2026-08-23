import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../config/jw_config.dart';
import '../models/jw_course.dart';
import 'jw_parser.dart';

/// 教务系统自定义异常。
class JwException implements Exception {
  final String message;
  const JwException(this.message);

  @override
  String toString() => message;
}

/// 教务系统网络服务（基于 dart:io HttpClient，无额外依赖）。
class JwApiService {
  JwApiService._() {
    _client = HttpClient();
    if (JwConfig.allowSelfSignedCertificate) {
      _client.badCertificateCallback = (cert, host, port) => true;
    }
  }

  static final JwApiService instance = JwApiService._();

  late final HttpClient _client;
  final Map<String, String> _cookies = {};

  /// 模式 A：JSON API 登录，返回 token。
  Future<String> loginWithApi({
    required String username,
    required String password,
  }) async {
    final data = await _getJson(
      JwConfig.loginApi,
      query: {'xh': username, 'pwd': password},
    );
    final flag = data['flag']?.toString();
    if (flag != null && flag != '1' && flag.toLowerCase() != 'true') {
      throw JwException(data['msg']?.toString() ?? '学号或密码错误');
    }
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw JwException(data['msg']?.toString() ?? '登录失败：未获取到 token');
    }
    return token;
  }

  /// 获取当前学年学期信息。
  Future<Map<String, dynamic>> fetchCurrentTime({DateTime? date}) async {
    return _getJson(
      JwConfig.currentTimeApi,
      query: {'currDate': _fmtDate(date ?? DateTime.now())},
    );
  }

  /// 获取课表。
  Future<List<JwCourse>> fetchTimetable({
    required String token,
    required String studentId,
    String? semester,
    int? week,
  }) async {
    final data = await _getJson(
      JwConfig.timetableApi,
      query: {
        'xh': studentId,
        if (semester != null && semester.isNotEmpty) 'xnxqid': semester,
        if (week != null) 'zc': week.toString(),
      },
      headers: {'token': token},
    );
    final list = data['kbList'] ??
        data['data'] ??
        data['rows'] ??
        data['items'] ??
        data['courseList'] ??
        const [];
    if (list is! List) {
      throw const JwException('课表数据格式异常');
    }
    return list
        .whereType<Map>()
        .map((e) => JwCourseParser.fromJson(
              Map<String, dynamic>.from(e),
              semester: semester,
            ))
        .toList();
  }

  /// 模式 B：获取验证码图片。
  Future<Uint8List> fetchCaptcha() async {
    final uri = Uri.parse('${JwConfig.baseUrl}${JwConfig.captchaApi}');
    final request = await _client.getUrl(uri);
    _applyCookies(request);
    final response = await request.close();
    _saveCookies(response);
    if (response.statusCode != 200) {
      throw const JwException('验证码获取失败');
    }
    final bytes = await response.fold<BytesBuilder>(
      BytesBuilder(),
      (builder, chunk) => builder..add(chunk),
    );
    return bytes.takeBytes();
  }

  /// 模式 B：传统表单登录（需要根据实际页面字段调整）。
  Future<String> loginWithForm({
    required String username,
    required String password,
    String? captcha,
  }) async {
    // 先访问一次登录页获取初始 Cookie
    await _getBytes('/Logon.do?method=logon');

    final uri = Uri.parse('${JwConfig.baseUrl}/Logon.do?method=logon');
    final request = await _client.postUrl(uri);
    _applyCookies(request);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
    final body = {
      'userName': username,
      'password': password,
      if (captcha != null && captcha.isNotEmpty) 'captcha': captcha,
    };
    request.write(body.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'));
    final response = await request.close();
    _saveCookies(response);
    if (response.statusCode >= 400) {
      throw const JwException('登录失败');
    }
    if (_cookies.isEmpty) {
      throw const JwException('登录失败：未获取到会话');
    }
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('${JwConfig.baseUrl}$path').replace(
      queryParameters: query,
    );
    final request = await _client.getUrl(uri);
    _applyCookies(request);
    headers?.forEach((k, v) => request.headers.set(k, v));
    final response = await request.close();
    _saveCookies(response);
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) {
      throw JwException('请求失败：HTTP ${response.statusCode}');
    }
    return _decode(body);
  }

  Future<Uint8List> _getBytes(String path) async {
    final uri = Uri.parse('${JwConfig.baseUrl}$path');
    final request = await _client.getUrl(uri);
    _applyCookies(request);
    final response = await request.close();
    _saveCookies(response);
    if (response.statusCode != 200) {
      throw JwException('请求失败：HTTP ${response.statusCode}');
    }
    final bytes = await response.fold<BytesBuilder>(
      BytesBuilder(),
      (builder, chunk) => builder..add(chunk),
    );
    return bytes.takeBytes();
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List) return {'data': decoded};
    } catch (_) {
      // ignore
    }
    return <String, dynamic>{};
  }

  void _applyCookies(HttpClientRequest request) {
    if (_cookies.isNotEmpty) {
      request.headers.set(
        HttpHeaders.cookieHeader,
        _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
      );
    }
  }

  void _saveCookies(HttpClientResponse response) {
    for (final c in response.cookies) {
      _cookies[c.name] = c.value;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
