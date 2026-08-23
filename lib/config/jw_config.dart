/// 教务系统对接配置。
///
/// 当前主要面向中国石油大学（北京）克拉玛依校区新教务系统（强智科技）。
/// 若学校更换域名或接口路径，只需修改本文件。
class JwConfig {
  JwConfig._();

  /// 新教务系统基础地址。
  ///
  /// 中石大克校区新教务系统（EAMS）。
  /// 
  static const String baseUrl = 'https://eams.cupk.edu.cn';
  static const String portalBaseUrl = 'https://portal.cupk.edu.cn';
  static const String portalLoginPath = '/portal/r/w?cmd=CLIENT_USER_HOME';
  static const String casLoginUrl =
      'https://cas.cupk.edu.cn/cas/login?service=https%3A%2F%2Fportal.cupk.edu.cn%2Fportal%2Findex_sso.jsp';

  /// 是否优先使用强智 JSON API 模式。
  /// 如果学校关闭了 app.do 接口，可改为 false 走传统表单模拟登录。
  static const bool preferApiMode = true;

  /// 登录 API（模式 A）
  static const String loginApi = '/app.do?method=authUser';

  /// 获取当前学期/周次 API
  static const String currentTimeApi = '/app.do?method=getCurrentTime';

  /// 获取课表 API
  static const String timetableApi = '/app.do?method=getKbcxAzc';

  /// 验证码图片地址（模式 B 使用）
  static const String captchaApi = '/Logon.do?method=logon&flag=sess';

  /// 请求超时时间
  static const Duration timeout = Duration(seconds: 15);

  /// 是否允许自签名证书。
  /// 学校内网可能存在自签证书，生产环境请根据实际情况调整。
  static const bool allowSelfSignedCertificate = true;
}
