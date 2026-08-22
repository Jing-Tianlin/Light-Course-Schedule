import 'package:flutter_test/flutter_test.dart';

import 'package:kebiao_app/models/course.dart';
import 'package:kebiao_app/utils/schedule_utils.dart';

void main() {
  group('Course.isLastOccurrence', () {
    test('handles non-continuous week ranges', () {
      const course = Course(
        name: '高等数学',
        day: 0,
        start: 1,
        end: 2,
        weeks: [WeekRange(1, 5), WeekRange(7, 8)],
      );

      expect(course.isLastOccurrence(5), isFalse);
      expect(course.isLastOccurrence(8), isTrue);
      expect(course.isLastOccurrence(6), isFalse);
    });
  });

  group('ScheduleUtils.mondayOf', () {
    test('normalizes any weekday to Monday', () {
      final monday = ScheduleUtils.mondayOf(DateTime(2026, 8, 18));
      expect(monday.weekday, DateTime.monday);
      expect(monday.day, 17);
    });

    test('keeps Monday unchanged', () {
      final monday = ScheduleUtils.mondayOf(DateTime(2026, 8, 17));
      expect(monday.day, 17);
    });
  });
}
