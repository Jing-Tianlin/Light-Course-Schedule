/// 教务系统导入流程中使用的统一异常类型。
class JwException implements Exception {
  final String message;
  const JwException(this.message);

  @override
  String toString() => message;
}
