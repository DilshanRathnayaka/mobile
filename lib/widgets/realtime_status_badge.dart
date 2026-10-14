import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../providers/portfolio_provider.dart';

/// Sleek pulsing indicator showing real-time live streaming status for profit/loss & market prices.
class RealtimeStatusBadge extends ConsumerStatefulWidget {
  final bool showLabel;
  final double size;

  const RealtimeStatusBadge({
    super.key,
    this.showLabel = true,
    this.size = 7.0,
  });

  @override
  ConsumerState<RealtimeStatusBadge> createState() => _RealtimeStatusBadgeState();
}

class _RealtimeStatusBadgeState extends ConsumerState<RealtimeStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.35).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLive = ref.watch(livePriceStatusProvider).valueOrNull ?? true;
    final dotColor = isLive ? const Color(0xFF00E676) : const Color(0xFFFFB300);

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surface(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                Icon(
                  isLive ? Icons.bolt_rounded : Icons.sync_rounded,
                  color: dotColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isLive
                        ? 'Real-Time Streaming Active: Profit/Loss & positions auto-update continuously without manual refresh.'
                        : 'Reconnecting Live Stream: Fallback background price sync is active.',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: dotColor.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dotColor.withAlpha(90), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Container(
                  width: widget.size * _pulseAnim.value,
                  height: widget.size * _pulseAnim.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withAlpha(150),
                        blurRadius: 5 * _pulseAnim.value,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
            if (widget.showLabel) ...[
              const SizedBox(width: 5),
              Text(
                isLive ? 'LIVE' : 'SYNC',
                style: TextStyle(
                  color: dotColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
