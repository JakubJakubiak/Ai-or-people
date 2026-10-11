import 'package:flutter/material.dart';
import 'package:humanai/utils/app_colors.dart';

/// Bottom sheet with the daily streak: past days, today and what comes next.
class SlidingMenuWidget extends StatefulWidget {
  const SlidingMenuWidget({
    super.key,
    required this.consecutiveDays,
    this.onClose,
  });

  final int consecutiveDays;
  final VoidCallback? onClose;

  @override
  State<SlidingMenuWidget> createState() => _SlidingMenuWidgetState();
}

class _SlidingMenuWidgetState extends State<SlidingMenuWidget> {
  static const int _daysBefore = 15;
  static const int _daysAfter = 15;
  static const double _tileWidth = 84;
  static const double _tileGap = 10;

  final ScrollController _scrollController = ScrollController();

  int get _startDay => widget.consecutiveDays > _daysBefore ? widget.consecutiveDays - _daysBefore : 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // Bring today's tile roughly to the middle of the row.
      final target = (widget.consecutiveDays - _startDay) * (_tileWidth + _tileGap) - 120;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Same rule the game uses for the starting combo.
  static double _bonusFor(int day) => day < 1 ? 1 : (1.2 + (day ~/ 2) * 0.5).clamp(1, 10).toDouble();

  Widget _buildDay(int day) {
    final done = day < widget.consecutiveDays;
    final today = day == widget.consecutiveDays;
    final color = today ? AppColors.combo : (done ? AppColors.human : AppColors.outline);
    return Container(
      width: _tileWidth,
      margin: const EdgeInsets.only(right: _tileGap),
      decoration: BoxDecoration(
        color: today ? AppColors.combo.withValues(alpha: 0.16) : AppColors.surfaceHigh.withValues(alpha: done ? 0.9 : 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: today ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('DAY $day', style: TextStyle(color: today ? Colors.white : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 6),
          Icon(
            today ? Icons.local_fire_department_rounded : (done ? Icons.check_circle_rounded : Icons.lock_outline_rounded),
            color: color,
            size: today ? 34 : 26,
          ),
          const SizedBox(height: 6),
          Text(
            'x${_bonusFor(day).toStringAsFixed(1)}',
            style: TextStyle(color: today || done ? Colors.white : AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.consecutiveDays;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 8, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: AppColors.combo, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  days > 0 ? '$days-day streak' : 'Start your streak',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Close',
                onPressed: widget.onClose,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12, bottom: 14),
            child: Text(
              'Play every day: each streak day raises the combo you start with.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.3),
            ),
          ),
          SizedBox(
            height: 112,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: (days + _daysAfter) - _startDay + 1,
              itemBuilder: (context, index) => _buildDay(_startDay + index),
            ),
          ),
        ],
      ),
    );
  }
}
