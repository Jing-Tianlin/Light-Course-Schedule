import 'package:flutter/material.dart';

import '../data/kebiao_data.dart';
import '../models/course.dart';
import '../utils/app_theme.dart';

/// 单日课程卡片
class CourseCard extends StatelessWidget {
  final Course course;

  /// 当前正在浏览的周（用于判断右上角是否显示「最后一次」）
  final int week;

  /// 点击回调（由父组件弹详情 BottomSheet）
  final void Function(Course course)? onTap;

  const CourseCard({super.key, required this.course, required this.week, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorOf(course);
    final maxWeek = KebiaoData.instance.maxWeek;
    // 决定周次标签文案（仅非全学期 / 非最后周才需要提示）
    String? badge;
    if (!course.isFullTerm(maxWeek)) {
      if (course.isLastOccurrence(week)) {
        badge = '最后一次';
      } else {
        badge = course.weeksText(maxWeek);
      }
    }

    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(course),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 3), // 左侧色条
            ),
          ),
          padding: const EdgeInsets.fromLTRB(5, 5, 4, 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 课程名：粗体主题色，最多 3 行（窄列下竖排显示更多字）
              Text(
                course.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2,
                  fontFamily: 'PingFang SC',
                ),
              ),
              const Spacer(),
              // 地点：当前周对应的地点，最多 2 行
              if (course.locFor(week).isNotEmpty) ...[
                Text(
                  course.locFor(week),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8A8F99),
                    height: 1.2,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                const SizedBox(height: 2),
              ],
              // 教师：直接显示姓名，无前缀
              Text(
                course.teacher.isEmpty ? '未安排' : course.teacher,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9AA0AB),
                  height: 1.2,
                  fontFamily: 'PingFang SC',
                ),
              ),
              const SizedBox(height: 1),
              // 周次标签：左下角，浅灰（仅非全学期课程显示）
              if (badge != null)
                Text(
                  badge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: badge == '最后一次'
                        ? const Color(0xFFDC6803)
                        : const Color(0xFFBBBBBB),
                    height: 1.1,
                    fontFamily: 'PingFang SC',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}