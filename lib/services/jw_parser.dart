import '../models/jw_course.dart';

/// 强智教务系统课表数据解析器。
///
/// 不同学校返回字段略有差异，这里兼容常见字段名：
/// - 课程名称：kcmc / courseName / name
/// - 教师：jsxm / teacher
/// - 教室：jsmc / classroom / room
/// - 星期：xqj / dayOfWeek / day
/// - 节次：ksjc / jssjc / startSection / endSection / jc
/// - 周次：kkzc / weeks / zc
class JwCourseParser {
  JwCourseParser._();

  static JwCourse fromJson(Map<String, dynamic> json, {String? semester}) {
    final name = _str(json, ['kcmc', 'courseName', 'name', 'kcm']);
    final teacher = _str(json, ['jsxm', 'teacher', 'teather']);
    final classroom = _str(json, ['jsmc', 'classroom', 'room', 'jxlmc']);
    final day = _int(json, ['xqj', 'dayOfWeek', 'day', 'xq']) ?? 1;
    final start = _int(json, ['ksjc', 'startSection', 'kssjd', 'jc']) ?? 1;
    final end = _int(json, ['jssjc', 'endSection', 'jssjd']) ?? start;
    final weeks = parseWeeks(_str(json, ['kkzc', 'weeks', 'zc', 'zcs']) ?? '');
    final rawSemester = semester ?? _str(json, ['xnxqid', 'semester', 'xqmc']);
    final id = _str(json, ['kch', 'courseId', 'id']) ?? '$name-$day-$start';

    return JwCourse(
      id: id,
      name: name,
      teacher: teacher,
      classroom: classroom,
      dayOfWeek: day,
      startSection: start,
      endSection: end,
      weeks: weeks,
      semester: rawSemester ?? '',
      rawData: json,
    );
  }

  /// 解析新教务系统（EAMS5）课表接口返回的 JSON。
  ///
  /// 支持两种常见结构：
  /// 1. `activities` 里直接带 `weekIndexes` 列表（中石大克校区新教务）。
  /// 2. 每个 activity 只带单个 `weekIndex`，需要按课程/星期/节次合并周次。
  static List<JwCourse> parseEams5CourseTable(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return const [];

    final tableVms = decoded['studentTableVms'] ??
        decoded['teacherTableVms'] ??
        decoded['data']?['studentTableVms'] ??
        decoded['data']?['teacherTableVms'];
    if (tableVms is! List || tableVms.isEmpty) return const [];

    final units = _extractTimeTableUnits(tableVms);
    final lessons = <String, Map<String, dynamic>>{};
    final groups = <String, _Eams5Group>{};

    for (final vm in tableVms.whereType<Map>()) {
      final vmMap = Map<String, dynamic>.from(vm);

      // 缓存课程基本信息（如果存在）
      final lessonList = vmMap['lessonSearchVms'] ?? vmMap['lessons'];
      if (lessonList is List) {
        for (final raw in lessonList.whereType<Map>()) {
          final lesson = Map<String, dynamic>.from(raw);
          final id = lesson['id']?.toString();
          if (id != null && id.isNotEmpty) {
            lessons[id] = lesson;
          }
        }
      }

      // 处理排课活动
      final activities = vmMap['activities'] ?? vmMap['schedules'];
      if (activities is! List) continue;

      for (final raw in activities.whereType<Map>()) {
        final act = Map<String, dynamic>.from(raw);
        if (act['practiceSchedule'] == true) continue;

        final lessonId = act['lessonId']?.toString() ?? '';
        final lesson = lessons[lessonId];

        final day = _intValue(act['weekday']) ?? _intValue(act['weekDay']) ?? 1;
        final startSection = _intValue(act['startUnit']) ??
            _intValue(act['startSection']) ??
            _mapToUnit(act['startTime'], units, isStart: true) ??
            1;
        final endSection = _intValue(act['endUnit']) ??
            _intValue(act['endSection']) ??
            _mapToUnit(act['endTime'], units, isStart: false) ??
            startSection;

        final classroom = act['room']?.toString() ??
            (act['room'] is Map
                ? (act['room'] as Map)['nameZh']?.toString()
                : null) ??
            act['customPlace']?.toString() ??
            '';
        final teacher = _joinTeachers(act['teachers']) ??
            act['personName']?.toString() ??
            _teacherNames(lesson) ??
            '';
        final name = lesson?['courseName']?.toString() ??
            act['courseName']?.toString() ??
            '';

        final courseCode = act['courseCode']?.toString() ??
            lesson?['courseCode']?.toString() ??
            '';
        final key =
            '$courseCode|$lessonId|$startSection|$endSection|$day|$classroom|$teacher';
        final group = groups.putIfAbsent(
          key,
          () => _Eams5Group(
            lessonId: lessonId,
            courseCode: courseCode,
            name: name,
            teacher: teacher,
            classroom: classroom,
            dayOfWeek: day,
            startSection: startSection,
            endSection: endSection,
          ),
        );

        // 优先使用已聚合的周次列表
        final weekIndexes = act['weekIndexes'];
        if (weekIndexes is List && weekIndexes.isNotEmpty) {
          for (final w in weekIndexes) {
            final idx = _intValue(w);
            if (idx != null) group.weeks.add(idx);
          }
          continue;
        }

        // 否则使用单个 weekIndex
        final weekIndex = _intValue(act['weekIndex']);
        if (weekIndex != null) group.weeks.add(weekIndex);
      }
    }

    return groups.values.map((g) {
      final sortedWeeks = g.weeks.toList()..sort();
      return _buildEams5Course(
        lessonId: g.lessonId,
        courseCode: g.courseCode,
        name: g.name,
        teacher: g.teacher,
        classroom: g.classroom,
        dayOfWeek: g.dayOfWeek,
        startSection: g.startSection,
        endSection: g.endSection,
        weeks: sortedWeeks,
        semester: _semesterName(decoded),
      );
    }).toList();
  }

  static JwCourse _buildEams5Course({
    required String lessonId,
    required String courseCode,
    required String name,
    required String teacher,
    required String classroom,
    required int dayOfWeek,
    required int startSection,
    required int endSection,
    required List<int> weeks,
    required String semester,
  }) {
    return JwCourse(
      id: '$lessonId-$dayOfWeek-$startSection',
      courseCode: courseCode,
      name: name,
      teacher: teacher,
      classroom: classroom,
      dayOfWeek: dayOfWeek,
      startSection: startSection,
      endSection: endSection,
      weeks: weeks,
      semester: semester,
    );
  }

  static List<Map<String, dynamic>> _extractTimeTableUnits(List<dynamic> tableVms) {
    for (final vm in tableVms.whereType<Map>()) {
      final layout = (vm as Map)['timeTableLayout'] ?? vm['timeSegmentLayout'];
      if (layout is! Map) continue;
      final units = layout['units'];
      if (units is List) {
        return units
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  static int? _mapToUnit(
    dynamic value,
    List<Map<String, dynamic>> units, {
    required bool isStart,
  }) {
    final n = _timeToInt(value);
    if (n == null) return null;
    for (final u in units) {
      final unitVal = _timeToInt(isStart ? u['startTime'] : u['endTime']);
      if (unitVal == n) {
        return _intValue(u['indexNo']);
      }
    }
    return null;
  }

  static int? _timeToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().replaceAll(':', '').trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static String? _teacherNames(Map<String, dynamic>? lesson) {
    if (lesson == null) return null;
    final teachers = lesson['teacherAssignmentList'];
    if (teachers is! List) return null;
    final names = <String>[];
    for (final t in teachers.whereType<Map>()) {
      final name = (t as Map)['name']?.toString();
      if (name != null && name.isNotEmpty) names.add(name);
    }
    if (names.isEmpty) return null;
    return names.join(',');
  }

  /// 从 `teachers` 数组中提取教师姓名，去掉工号括号。
  static String? _joinTeachers(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    final names = <String>[];
    for (final item in value) {
      final text = item.toString();
      if (text.isEmpty) continue;
      final paren = text.indexOf('(');
      final name = paren >= 0 ? text.substring(0, paren) : text;
      if (name.isNotEmpty) names.add(name);
    }
    if (names.isEmpty) return null;
    return names.join(',');
  }

  static String _semesterName(Map<String, dynamic> json) {
    final semester = json['semester'];
    if (semester is Map) {
      final name = semester['nameZh'] ?? semester['name'];
      if (name != null) return name.toString();
    }
    return '';
  }

  /// 解析周次字符串。
  ///
  /// 支持格式：
  /// - 1-16
  /// - 1-8,10-16
  /// - 第1-8,10-16周
  /// - 1,3,5,7
  /// - 1-16(单周) / 1-16(双周)
  static List<int> parseWeeks(String input) {
    if (input.isEmpty) return const [];
    var text = input
        .replaceAll('第', '')
        .replaceAll('周', '')
        .replaceAll('单', '')
        .replaceAll('双', '')
        .replaceAll(' ', '');
    final result = <int>{};
    for (final part in text.split(RegExp(r'[,，;；、]'))) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final range = RegExp(r'^(\d+)\s*[-~—]\s*(\d+)$').firstMatch(p);
      if (range != null) {
        final a = int.parse(range.group(1)!);
        final b = int.parse(range.group(2)!);
        for (var w = a; w <= b; w++) {
          result.add(w);
        }
      } else {
        final single = int.tryParse(p);
        if (single != null) result.add(single);
      }
    }
    final list = result.toList()..sort();
    return list;
  }

  static String _str(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final n = int.tryParse(v.trim());
        if (n != null) return n;
      }
    }
    return null;
  }
}

/// 新教务系统（EAMS5）排课分组合并辅助类。
class _Eams5Group {
  final String lessonId;
  final String courseCode;
  final String name;
  final String teacher;
  final String classroom;
  final int dayOfWeek;
  final int startSection;
  final int endSection;
  final Set<int> weeks = {};

  _Eams5Group({
    required this.lessonId,
    required this.courseCode,
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
  });
}
