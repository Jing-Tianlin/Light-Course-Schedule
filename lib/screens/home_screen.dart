import 'package:flutter/material.dart';

import '../data/kebiao_data.dart';
import '../utils/app_theme.dart';
import '../utils/schedule_utils.dart';
import '../widgets/week_schedule_view.dart';

/// 课表主页：顶部周导航 + 完整周(7天)课表
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 当前浏览的周
  late int _week;

  /// 本周周一
  late DateTime _weekStart;

  /// 本学期是否尚未开始（当前日期早于开学周）
  late bool _notStarted;
  late bool _semesterEnded;

  @override
  void initState() {
    super.initState();
    KebiaoData.instance.addListener(_onDataChanged);
    _initToToday();
  }

  @override
  void dispose() {
    KebiaoData.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    // 开学日期 / 作息时间等变化后，按当前日期重新定位
    _initToToday();
    if (mounted) setState(() {});
  }

  DateTime _weekStartOf(int week) {
    final start = KebiaoData.instance.termStart;
    return DateTime(start.year, start.month, start.day + (week - 1) * 7);
  }

  void _initToToday() {
    final data = KebiaoData.instance;
    final now = DateTime.now();
    final raw = ScheduleUtils.computeRawWeek(now, data.termStart);
    _notStarted = raw < 1;
    _semesterEnded = raw > data.maxWeek;
    _week = raw < 1 ? 1 : (raw > data.maxWeek ? data.maxWeek : raw);
    _weekStart = _weekStartOf(_week);
  }

  void _switchToWeek(int target) {
    setState(() {
      _week = target;
      _weekStart = _weekStartOf(target);
      _notStarted = false;
      _semesterEnded = false; // 手动浏览到具体周后，视为已开始教学安排
    });
  }

  void _changeWeek(int delta) {
    final next = _week + delta;
    if (next < 1 || next > KebiaoData.instance.maxWeek) return;
    _switchToWeek(next);
  }

  bool _isCurrentRealWeek() {
    final raw = ScheduleUtils.computeRawWeek(
      DateTime.now(),
      KebiaoData.instance.termStart,
    );
    return _week == raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // 顶部栏：日期范围 + 周次切换（合并为一行，更窄）
            _buildHeader(context),
            // 完整周课表（横向滑动看7天）/ 未开学占位
            Expanded(
              child: _notStarted
                  ? _buildNotStarted(context)
                  : _semesterEnded
                  ? _buildSemesterEnded(context)
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (details) {
                        final v = details.primaryVelocity ?? 0;
                        if (v < -200) _changeWeek(1);
                        if (v > 200) _changeWeek(-1);
                      },
                      child: WeekScheduleView(
                        key: ValueKey(
                          '$_week-${_weekStart.millisecondsSinceEpoch}',
                        ),
                        week: _week,
                        weekDays: ScheduleUtils.daysOfWeek(_weekStart),
                        onRefresh: () {},
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 未开学占位视图
  Widget _buildNotStarted(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⏳', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          const Text(
            '本学期尚未开始',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '开学后会按当前日期自动定位到对应周次',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _notStarted = false);
            },
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('查看第 1 周课表'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.brand,
              side: const BorderSide(color: AppTheme.brand),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 学期结束占位视图
  Widget _buildSemesterEnded(BuildContext context) {
    final maxWeek = KebiaoData.instance.maxWeek;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          const Text(
            '本学期已结束',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '当前日期已超过第 $maxWeek 周，可查看最后一周课表',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _semesterEnded = false;
                _week = maxWeek;
                _weekStart = _weekStartOf(maxWeek);
              });
            },
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('查看最后一周课表'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.brand,
              side: const BorderSide(color: AppTheme.brand),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final range = ScheduleUtils.fmtWeekRange(_weekStart);
    final maxWeek = KebiaoData.instance.maxWeek;
    final isReal = _isCurrentRealWeek();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          _navBtn(-1, Icons.chevron_left),
          Expanded(
            child: GestureDetector(
              onTap: _showWeekPicker,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '第 $_week 周',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (isReal) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '本周',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$range · 共 $maxWeek 周',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          _navBtn(1, Icons.chevron_right),
        ],
      ),
    );
  }

  Widget _navBtn(int delta, IconData icon) {
    final maxWeek = KebiaoData.instance.maxWeek;
    final disabled = delta < 0 ? _week <= 1 : _week >= maxWeek;
    return InkWell(
      onTap: disabled ? null : () => _changeWeek(delta),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.shade100
              : AppTheme.brand.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled ? Colors.grey.shade400 : AppTheme.brand,
        ),
      ),
    );
  }

  void _showWeekPicker() {
    final hostContext = context;
    // 当前真实周（学期未开始时为 <1）
    final raw = ScheduleUtils.computeRawWeek(
      DateTime.now(),
      KebiaoData.instance.termStart,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final maxWeek = KebiaoData.instance.maxWeek;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '选择周次',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        if (raw < 1) {
                          ScaffoldMessenger.of(hostContext).showSnackBar(
                            const SnackBar(
                              content: Text('本学期尚未开始'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          _switchToWeek(raw);
                        }
                      },
                      icon: const Icon(Icons.today, size: 18),
                      label: const Text('本周'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(maxWeek, (i) {
                    final w = i + 1;
                    final sel = w == _week;
                    return ChoiceChip(
                      label: Text('第 $w 周'),
                      selected: sel,
                      selectedColor: AppTheme.brand,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : Colors.grey.shade800,
                      ),
                      onSelected: (_) {
                        Navigator.pop(context);
                        _switchToWeek(w);
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
