/// 课程类型（决定卡片主题色）
enum CourseType {
  required('必修'), // 蓝
  elective('选修'), // 绿
  lab('实验'), // 紫
  general('通识'); // 橙

  const CourseType(this.label);
  final String label;

  static CourseType fromLabel(String? s) {
    switch (s) {
      case '必修':
        return CourseType.required;
      case '选修':
        return CourseType.elective;
      case '实验':
        return CourseType.lab;
      case '通识':
        return CourseType.general;
      default:
        return CourseType.required;
    }
  }
}

/// 节次区间
class WeekRange {
  final int start;
  final int end;
  const WeekRange(this.start, this.end);

  bool contains(int week) => week >= start && week <= end;

  List<int> toJson() => [start, end];

  factory WeekRange.fromJson(List<dynamic> js) =>
      WeekRange(js[0] as int, js[1] as int);

  factory WeekRange.fromPair(List<Object> pair) =>
      WeekRange(pair.first as int, pair.last as int);
}

/// 周段对应的上课地点
class Placement {
  final WeekRange weeks;
  final String loc;
  const Placement(this.weeks, this.loc);

  Map<String, dynamic> toJson() =>
      {'weeks': weeks.toJson(), 'loc': loc};

  factory Placement.fromJson(Map<String, dynamic> j) =>
      Placement(WeekRange.fromJson(j['weeks'] as List), j['loc'] as String);
}

/// 课程
class Course {
  final String name;
  final String code;
  final CourseType type;
  final int day; // 0=周一 .. 6=周日
  final int start; // 开始节(1..12)
  final int end; // 结束节
  final List<WeekRange> weeks;
  final String loc;

  /// 按周段区分的地点（可选）；空列表则始终用 [loc]
  final List<Placement> placements;
  final String teacher;
  final List<String> classes;

  const Course({
    required this.name,
    this.code = '',
    this.type = CourseType.required,
    required this.day,
    required this.start,
    required this.end,
    required this.weeks,
    this.loc = '',
    this.placements = const [],
    this.teacher = '',
    this.classes = const [],
  });

  /// 是否在指定周上课
  bool inWeek(int week) => weeks.any((w) => w.contains(week));

  /// 指定周对应的上课地点（优先周段匹配，否则回退到 [loc]）
  String locFor(int week) {
    for (final p in placements) {
      if (p.weeks.contains(week)) return p.loc;
    }
    return loc;
  }

  /// 完整地点描述（含周段区分），用于详情页；无分段时仅返回 loc
  String locSummary() {
    if (placements.isEmpty) return loc;
    return placements
        .map((p) => '${p.weeks.start}-${p.weeks.end}周 · ${p.loc}')
        .join('\n');
  }

  /// 是否为全学期课程（覆盖到 maxWeek）
  bool isFullTerm(int maxWeek) =>
      weeks.length == 1 && weeks.first.start == 1 && weeks.first.end >= maxWeek;

  /// 是否在本周是该课程的最后一节课
  bool isLastOccurrence(int week) {
    if (!inWeek(week)) return false;
    return !weeks.any((w) => w.end > week);
  }

  /// 周次描述，用于角标
  String weeksText(int maxWeek) {
    final parts = weeks
        .map((w) => w.start == w.end ? '${w.start}周' : '${w.start}-${w.end}周')
        .toList();
    return parts.join('，');
  }

  /// 节次描述，如 "第1-2节"
  String timeText() => start == end ? '第$start节' : '第$start-$end节';

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'type': type.name,
        'day': day,
        'start': start,
        'end': end,
        'weeks': weeks.map((w) => w.toJson()).toList(),
        'loc': loc,
        'placements': placements.map((p) => p.toJson()).toList(),
        'teacher': teacher,
        'classes': classes,
      };

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        name: j['name'] as String,
        code: (j['code'] ?? '') as String,
        type: CourseType.values.firstWhere(
            (t) => t.name == j['type'],
            orElse: () => CourseType.required),
        day: j['day'] as int,
        start: j['start'] as int,
        end: j['end'] as int,
        weeks: (j['weeks'] as List)
            .map((w) => WeekRange.fromJson(w as List))
            .toList(),
        loc: (j['loc'] ?? '') as String,
        placements: ((j['placements'] ?? const []) as List)
            .map((p) => Placement.fromJson(p as Map<String, dynamic>))
            .toList(),
        teacher: (j['teacher'] ?? '') as String,
        classes: ((j['classes'] ?? const []) as List).cast<String>(),
      );
}

/// 节次时间段
class Section {
  final int no;
  final String block; // 上午/下午/晚上
  final String time; // 开始时间 "08:00"
  final String end; // 下课时间 "08:45"
  const Section(this.no, this.block, this.time, [this.end = '']);

  /// 结束时间；未显式设置时按 start + 45 分钟
  String get endTime {
    if (end.isNotEmpty) return end;
    return _addMinutes(time, 45);
  }

  /// 时间段展示，如 "08:00-08:45"
  String get range => '$time-$endTime';

  Map<String, dynamic> toJson() =>
      {'no': no, 'block': block, 'time': time, 'end': end};

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        j['no'] as int,
        (j['block'] ?? '') as String,
        (j['time'] ?? '') as String,
        (j['end'] ?? '') as String,
      );

  static String _addMinutes(String t, int minutes) {
    final parts = t.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final total = h * 60 + m + minutes;
    final nh = (total ~/ 60) % 24;
    final nm = total % 60;
    return '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
  }
}