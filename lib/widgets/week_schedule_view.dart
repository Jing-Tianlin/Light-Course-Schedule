import 'package:flutter/material.dart';

import '../data/kebiao_data.dart';
import '../models/course.dart';
import '../utils/app_theme.dart';
import '../utils/schedule_utils.dart';
import '../widgets/course_card.dart';
import '../widgets/course_detail_sheet.dart';

/// 周视图：左侧时间轴 + 横向滑动的 7 天课程网格
class WeekScheduleView extends StatelessWidget {
  /// 当前周
  final int week;

  /// 本周 7 天日期（周一~周日）
  final List<DateTime> weekDays;

  final VoidCallback? onRefresh;

  const WeekScheduleView({
    super.key,
    required this.week,
    required this.weekDays,
    this.onRefresh,
  });

  /// 每个节次行高
  static const double unit = 68;

  /// 左侧时间轴宽度
  static const double axisWidth = 40;

  /// 顶部表头高度（周几 + 日期）
  static const double headerH = 40;

  @override
  Widget build(BuildContext context) {
    final sections = KebiaoData.instance.sections;
    // 全表高度 = 表头 + 12 节
    final gridH = headerH + sections.length * unit;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 动态列宽：时间轴固定，7 天平分剩余宽度，一屏放下
        final dayW = (constraints.maxWidth - axisWidth) / 7;

        Widget timeAxis() {
          return Container(
            width: axisWidth,
            color: const Color(0xFFF7F8FA),
            child: Column(
              children: [
                // 表头占位（与右侧表头同高，保持对齐）
                SizedBox(height: headerH),
                // 每节固定行高，与右侧格子完全对齐
                for (final s in sections)
                  SizedBox(
                    height: unit,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: _blockColor(s.block)),
                        // 区块顶部胶囊：绝对定位，不占布局高度
                        if (_isBlockStart(s, sections)) ..._blockChip(s),
                        // 时间：本格内垂直居中
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s.time,
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.black54)),
                              const SizedBox(height: 2),
                              Text(s.endTime,
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }

        Widget dayColumn(int i) => SizedBox(
              width: dayW,
              child: Column(
                children: [
                  // 表头：周几 + 日期
                  _dayHeader(weekDays[i], i),
                  // 网格：时段背景 + 该天课程
                  SizedBox(
                    height: sections.length * unit,
                    child: Stack(
                      children: [
                        // 背景节次行
                        Positioned.fill(
                          child: Column(
                            children: sections
                                .map(
                                  (s) => Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFFFF),
                                        border: Border(
                                          left: BorderSide(
                                              color: Colors.grey.shade100,
                                              width: 0.5),
                                          bottom: BorderSide(
                                              color: Colors.grey.shade100,
                                              width: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        // 课程卡片
                        ..._coursesOfDay(i).map((c) {
                          final top = (c.start - 1) * unit + 3;
                          final h = (c.end - c.start + 1) * unit - 6;
                          return Positioned(
                            left: 1,
                            top: top,
                            width: dayW - 2,
                            height: h,
                            child: CourseCard(
                              course: c,
                              week: week,
                              onTap: (course) => _openDetail(context, course),
                            ),
                          );
                        }),
                        // 无课日：显示一个轻松的表情
                        if (_coursesOfDay(i).isEmpty)
                          Positioned(
                            top: sections.length * unit * 0.28,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Text(
                                _dayEmoji(i),
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );

        final grid = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            timeAxis(),
            ...List.generate(7, dayColumn),
          ],
        );

        // 一屏放下 7 天：仅纵向滚动
        final scroll = SingleChildScrollView(
          child: SizedBox(
            width: constraints.maxWidth,
            height: gridH,
            child: grid,
          ),
        );
        return RefreshIndicator(
          onRefresh: () async {
            onRefresh?.call();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: scroll,
        );
      },
    );
  }

  Widget _dayHeader(DateTime day, int i) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final hasCourse = _coursesOfDay(i).isNotEmpty;

    return Container(
      height: headerH,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isToday
            ? AppTheme.brand.withValues(alpha: 0.10)
            : const Color(0xFFF7F7F7),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8E8E8), width: 1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ScheduleUtils.weekCN[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? AppTheme.brand : Colors.grey.shade700,
                ),
              ),
              if (hasCourse) ...[
                const SizedBox(width: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.brand,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${day.month}/${day.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isToday ? AppTheme.brand : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  List<Course> _coursesOfDay(int i) =>
      KebiaoData.instance.coursesOfDay(week, i);

  /// 无课日表情：工作日/周六/周日区分
  String _dayEmoji(int i) {
    final weekday = weekDays[i].weekday;
    if (weekday == DateTime.saturday) return '🛋️';
    if (weekday == DateTime.sunday) return '🎉';
    return '😴';
  }

  bool _isBlockStart(Section s, List<Section> sections) {
    final i = sections.indexOf(s);
    return i == 0 || sections[i].block != sections[i - 1].block;
  }

  Color _blockColor(String block) {
    switch (block) {
      case '上午':
        return const Color(0xFFFFFFFF);
      case '下午':
        return const Color(0xFFFAFBFC);
      case '晚上':
        return const Color(0xFFF0F4F8);
      default:
        return const Color(0xFFF7F8FA);
    }
  }

  List<Widget> _blockChip(Section s) {
    return [
      Positioned(
        top: 2,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              s.block,
              style: const TextStyle(
                fontSize: 8,
                color: AppTheme.brand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  void _openDetail(BuildContext context, Course course) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => CourseDetailSheet(course: course),
    );
  }
}