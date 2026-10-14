import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// GPU-accelerated LinearGradient Shimmer Shader
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF181920) : const Color(0xFFE5E7EB));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF2C2D3A) : const Color(0xFFF3F4F6));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, highlight, base],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// Generic rounded or circular placeholder box
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  const SkeletonBox.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF1E1F28) : const Color(0xFFE2E4E9);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A container card skeleton styled to match AppColors surface & border
class SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor.withAlpha(90)),
      ),
      child: child,
    );
  }
}

// ==========================================
// SCREEN SPECIFIC SKELETON LAYOUTS
// ==========================================

/// 1. Dashboard Screen Skeleton
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Net Worth Hero Card Skeleton
            SkeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 100, height: 14),
                      SkeletonBox(width: 60, height: 20, borderRadius: 10),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SkeletonBox(width: 220, height: 36, borderRadius: 6),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      SkeletonBox(width: 90, height: 22, borderRadius: 6),
                      SizedBox(width: 8),
                      SkeletonBox(width: 120, height: 16),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 80, height: 14),
                      SkeletonBox(width: 90, height: 14),
                      SkeletonBox(width: 70, height: 14),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions Skeleton Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                4,
                (i) => Column(
                  children: const [
                    SkeletonBox.circle(size: 48),
                    SizedBox(height: 8),
                    SkeletonBox(width: 48, height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(width: 130, height: 18),
                SkeletonBox(width: 50, height: 14),
              ],
            ),
            const SizedBox(height: 14),

            // Holding Card Skeletons
            ...List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SkeletonCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const SkeletonBox.circle(size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonBox(width: 100, height: 14),
                            SizedBox(height: 6),
                            SkeletonBox(width: 60, height: 11),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          SkeletonBox(width: 85, height: 14),
                          SizedBox(height: 6),
                          SkeletonBox(width: 55, height: 16, borderRadius: 4),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Holdings List Skeleton
class HoldingsSkeleton extends StatelessWidget {
  const HoldingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Filter Row
          Row(
            children: const [
              SkeletonBox(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              SkeletonBox(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              SkeletonBox(width: 80, height: 32, borderRadius: 16),
            ],
          ),
          const SizedBox(height: 16),

          // Holding Items
          ...List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SkeletonCard(
                child: Row(
                  children: [
                    const SkeletonBox.circle(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 110, height: 15),
                          SizedBox(height: 6),
                          SkeletonBox(width: 70, height: 11),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        SkeletonBox(width: 90, height: 15),
                        SizedBox(height: 6),
                        SkeletonBox(width: 60, height: 18, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. Market Tickers Skeleton
class MarketSkeleton extends StatelessWidget {
  const MarketSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SkeletonBox(height: 44, borderRadius: 12),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonBox(width: 70, height: 28, borderRadius: 14),
                    SkeletonBox(width: 85, height: 28, borderRadius: 14),
                    SkeletonBox(width: 85, height: 28, borderRadius: 14),
                    SkeletonBox(width: 60, height: 28, borderRadius: 14),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Ticker rows
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: 8,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => SkeletonCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const SkeletonBox.circle(size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 80, height: 14),
                          SizedBox(height: 6),
                          SkeletonBox(width: 50, height: 10),
                        ],
                      ),
                    ),
                    // Mini sparkline placeholder
                    const SkeletonBox(width: 55, height: 22, borderRadius: 4),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        SkeletonBox(width: 75, height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 55, height: 18, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4. Transactions History Skeleton
class TransactionsSkeleton extends StatelessWidget {
  const TransactionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Filter Tabs
          Row(
            children: const [
              SkeletonBox(width: 70, height: 30, borderRadius: 15),
              SizedBox(width: 8),
              SkeletonBox(width: 70, height: 30, borderRadius: 15),
              SizedBox(width: 8),
              SkeletonBox(width: 70, height: 30, borderRadius: 15),
            ],
          ),
          const SizedBox(height: 16),

          // Date Grouping Header
          const SkeletonBox(width: 90, height: 12),
          const SizedBox(height: 10),

          // Transaction cards
          ...List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SkeletonCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const SkeletonBox(width: 40, height: 40, borderRadius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 110, height: 14),
                          SizedBox(height: 6),
                          SkeletonBox(width: 80, height: 10),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        SkeletonBox(width: 80, height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 60, height: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5. Bank & Budget Hub Skeleton
class BankBudgetSkeleton extends StatelessWidget {
  const BankBudgetSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bank Net Worth Hero Card
            SkeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 110, height: 14),
                      SkeletonBox(width: 80, height: 20, borderRadius: 10),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SkeletonBox(width: 200, height: 32),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 90, height: 16),
                      SkeletonBox(width: 90, height: 16),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Accounts Section Header
            const SkeletonBox(width: 120, height: 16),
            const SizedBox(height: 12),

            // Accounts Carousel Placeholders
            Row(
              children: [
                Expanded(
                  child: SkeletonCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox.circle(size: 28),
                        SizedBox(height: 12),
                        SkeletonBox(width: 90, height: 13),
                        SizedBox(height: 6),
                        SkeletonBox(width: 110, height: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox.circle(size: 28),
                        SizedBox(height: 12),
                        SkeletonBox(width: 90, height: 13),
                        SizedBox(height: 6),
                        SkeletonBox(width: 110, height: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Cashflow & Budget Distribution
            const SkeletonBox(width: 140, height: 16),
            const SizedBox(height: 12),
            SkeletonCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 100, height: 14),
                      SkeletonBox(width: 70, height: 14),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SkeletonBox(height: 8, borderRadius: 4),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 100, height: 14),
                      SkeletonBox(width: 70, height: 14),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SkeletonBox(height: 8, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 6. Salary & EPF/ETF Skeleton
class SalaryEpfSkeleton extends StatelessWidget {
  const SalaryEpfSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CBSL EPF/ETF Hero Card Skeleton
            SkeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 130, height: 14),
                      SkeletonBox(width: 70, height: 20, borderRadius: 10),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SkeletonBox(width: 210, height: 34),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 110, height: 14),
                      SkeletonBox(width: 110, height: 14),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Active Job Slip Skeleton
            const SkeletonBox(width: 140, height: 16),
            const SizedBox(height: 12),
            SkeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SkeletonBox(width: 44, height: 44, borderRadius: 12),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 120, height: 15),
                          SizedBox(height: 6),
                          SkeletonBox(width: 90, height: 11),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  ...List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          SkeletonBox(width: 110, height: 12),
                          SkeletonBox(width: 80, height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 7. Salary Allocation & DCA Inflows Skeleton
class SalaryDcaSkeleton extends StatelessWidget {
  const SalaryDcaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Monthly Budget Card Skeleton
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 14),
                SizedBox(height: 12),
                SkeletonBox(width: 180, height: 30),
                SizedBox(height: 14),
                SkeletonBox(height: 10, borderRadius: 5),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section Title
          const SkeletonBox(width: 140, height: 16),
          const SizedBox(height: 12),

          // Target Allocation Skeletons
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SkeletonCard(
                child: Row(
                  children: [
                    const SkeletonBox.circle(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 100, height: 14),
                          SizedBox(height: 6),
                          SkeletonBox(width: 60, height: 11),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        SkeletonBox(width: 70, height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 45, height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 8. Crypto Intelligence & News Feed Skeleton
class CryptoIntelligenceSkeleton extends StatelessWidget {
  const CryptoIntelligenceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Market Fear & Greed Card Skeleton
          SkeletonCard(
            child: Row(
              children: [
                const SkeletonBox.circle(size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 120, height: 14),
                      SizedBox(height: 8),
                      SkeletonBox(width: 80, height: 24, borderRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // News Wire Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonBox(width: 130, height: 16),
              SkeletonBox(width: 60, height: 12),
            ],
          ),
          const SizedBox(height: 12),

          // News items
          ...List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SkeletonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonBox(width: 70, height: 16, borderRadius: 4),
                        SkeletonBox(width: 50, height: 11),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const SkeletonBox(width: double.infinity, height: 15),
                    const SizedBox(height: 6),
                    const SkeletonBox(width: 200, height: 15),
                    const SizedBox(height: 10),
                    const SkeletonBox(width: 80, height: 11),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 9. Portfolio Analytics Skeleton
class AnalyticsSkeleton extends StatelessWidget {
  const AnalyticsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Performance Card
            SkeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 110, height: 14),
                      SkeletonBox(width: 60, height: 20, borderRadius: 10),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SkeletonBox(width: 190, height: 32),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 80, height: 14),
                      SkeletonBox(width: 80, height: 14),
                      SkeletonBox(width: 80, height: 14),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Asset Distribution Pie Chart Skeleton
            const SkeletonBox(width: 130, height: 16),
            const SizedBox(height: 12),
            SkeletonCard(
              child: Column(
                children: [
                  const Center(child: SkeletonBox.circle(size: 150)),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      SkeletonBox(width: 65, height: 12),
                      SkeletonBox(width: 65, height: 12),
                      SkeletonBox(width: 65, height: 12),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Key Performance Metrics Skeleton
            const SkeletonBox(width: 140, height: 16),
            const SizedBox(height: 12),
            ...List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SkeletonCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 120, height: 14),
                      SkeletonBox(width: 70, height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
