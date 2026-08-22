/// 日期与周次计算工具
class ScheduleUtils {
  ScheduleUtils._();

  static const List<String> weekCN = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// 计算某日期对应的当前周数(可小于1用于判断是否未开学)
  static int computeRawWeek(DateTime now, DateTime termStart) {
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(termStart.year, termStart.month, termStart.day);
    final days = a.difference(b).inDays;
    return (days / 7).floor() + 1;
  }

  /// 将任意日期归一化为所在周的周一（用于开学日期等必须为周一的值）
  static DateTime mondayOf(DateTime date) {
    final monday = DateTime(
      date.year,
      date.month,
      date.day - (date.weekday - DateTime.monday),
    );
    return monday;
  }

  /// 给定的周一所在的 7 天日期列表
  static List<DateTime> daysOfWeek(DateTime monday) =>
      List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));

  /// 格式化 "8月21日"
  static String fmtMD(DateTime d) => '${d.month}月${d.day}日';

  /// 格式化 "8月17日 ~ 8月23日" 周范围
  static String fmtWeekRange(DateTime weekStart) {
    final s = fmtMD(weekStart);
    final e = fmtMD(DateTime(
        weekStart.year, weekStart.month, weekStart.day + 6));
    return "$s ~ $e";
  }
}