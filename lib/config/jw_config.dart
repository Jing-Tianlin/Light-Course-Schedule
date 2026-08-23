/// 教务系统 WebView 导入配置。
///
/// 当前面向中国石油大学（北京）克拉玛依校区新教务系统。
class JwConfig {
  JwConfig._();

  /// CAS 统一登录入口，登录后通过 SSO 进入融合门户/教务系统。
  static const String casLoginUrl =
      'https://cas.cupk.edu.cn/cas/login?service=https%3A%2F%2Fportal.cupk.edu.cn%2Fportal%2Findex_sso.jsp';

  /// 电脑端 Chrome User-Agent，用于 WebView 强制桌面版渲染。
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';
}
