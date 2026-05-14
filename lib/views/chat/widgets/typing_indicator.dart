import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightPeach.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Typing',
            style: TextStyle(
              color: AppTheme.darkOrange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _getOpacity(index, _controller.value),
                    child: child,
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1.5),
                  child: CircleAvatar(
                    radius: 2.5,
                    backgroundColor: AppTheme.darkOrange,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  double _getOpacity(int index, double animationValue) {
    final start = index * 0.2;
    final end = start + 0.4;
    
    if (animationValue >= start && animationValue <= end) {
      // Scale from 0.2 to 1.0 back to 0.2
      final mid = start + 0.2;
      if (animationValue <= mid) {
        return 0.2 + 0.8 * ((animationValue - start) / 0.2);
      } else {
        return 1.0 - 0.8 * ((animationValue - mid) / 0.2);
      }
    }
    return 0.2;
  }
}
