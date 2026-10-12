import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'dashboard_screen.dart';
import 'market_screen.dart';
import 'holdings_screen.dart';
import 'deposit_withdraw_screen.dart';
import 'analytics_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    MarketScreen(),
    HoldingsScreen(),
    DepositWithdrawScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textMuted = AppColors.textMuted(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(top: BorderSide(color: borderColor, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: surfaceColor,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Terminal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.candlestick_chart_outlined),
              activeIcon: Icon(Icons.candlestick_chart),
              label: 'Market',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline),
              activeIcon: Icon(Icons.pie_chart),
              label: 'Positions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Deposit/Out',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}
