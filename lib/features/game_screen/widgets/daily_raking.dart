import 'package:flutter/material.dart';

class SlidingMenuWidget extends StatefulWidget {
  final int consecutiveDays;
  final VoidCallback? onClose;

  const SlidingMenuWidget({
    Key? key,
    required this.consecutiveDays,
    this.onClose,
  }) : super(key: key);

  @override
  State<SlidingMenuWidget> createState() => _SlidingMenuWidgetState();
}

class _SlidingMenuWidgetState extends State<SlidingMenuWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  static const int visibleDaysWindow = 15;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Calculate scroll position to show the latest days
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final startDay = _getStartDay();
        final scrollPosition = (widget.consecutiveDays - startDay) * 140.0;
        _scrollController.animateTo(
          scrollPosition.clamp(0.0, double.infinity),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
        );
      }
    });
  }

  int _getStartDay() {
    return widget.consecutiveDays > visibleDaysWindow ? widget.consecutiveDays - visibleDaysWindow : 0;
  }

  int _getEndDay() {
    return widget.consecutiveDays + 15;
  }

  Widget _buildDayWindow(int day) {
    final bool isCompleted = day < widget.consecutiveDays;
    final bool isToday = day == widget.consecutiveDays;

    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isToday
            ? Colors.blue.shade200
            : isCompleted
                ? Colors.blue.shade100
                : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? Colors.blue.shade500
              : isCompleted
                  ? Colors.blue
                  : Colors.grey.shade400,
          width: isToday ? 3 : 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Day $day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isToday
                  ? Colors.blue.shade900
                  : isCompleted
                      ? Colors.blue.shade800
                      : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            isToday
                ? Icons.star
                : isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
            color: isToday
                ? Colors.blue.shade500
                : isCompleted
                    ? Colors.blue
                    : Colors.grey.shade400,
            size: 32,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startDay = _getStartDay();
    final endDay = _getEndDay();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Congratulations! ${widget.consecutiveDays} Days Streak!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    _controller.reverse().then((_) {
                      widget.onClose?.call();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: endDay - startDay,
                itemBuilder: (context, index) => _buildDayWindow(startDay + index),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
