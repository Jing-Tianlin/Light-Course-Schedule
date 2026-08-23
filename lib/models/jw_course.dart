import 'course.dart';

/// 教务系统原始课程数据标准化后的模型。
class JwCourse {
  final String id;
  final String name;
  final String teacher;
  final String classroom;
  final int dayOfWeek; // 1=周一 .. 7=周日
  final int startSection;
  final int endSection;
  final List<int> weeks;
  final String semester;
  final Map<String, dynamic> rawData;

  const JwCourse({
    required this.id,
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.weeks,
    required this.semester,
    this.rawData = const {},
  });

  /// 转换为 App 主课表使用的 Course 模型。
  Course toCourse() {
    return Course(
      name: name,
      code: id,
      teacher: teacher,
      loc: classroom,
      day: dayOfWeek - 1,
      start: startSection,
      end: endSection,
      weeks: _toWeekRanges(weeks),
    );
  }

  /// 将连续周次合并为 WeekRange 列表。
  static List<WeekRange> _toWeekRanges(List<int> weeks) {
    if (weeks.isEmpty) return const [];
    final sorted = [...weeks]..sort();
    final result = <WeekRange>[];
    var start = sorted.first;
    var prev = start;
    for (var i = 1; i < sorted.length; i++) {
      final w = sorted[i];
      if (w == prev + 1) {
        prev = w;
      } else {
        result.add(WeekRange(start, prev));
        start = w;
        prev = w;
      }
    }
    result.add(WeekRange(start, prev));
    return result;
  }
}
