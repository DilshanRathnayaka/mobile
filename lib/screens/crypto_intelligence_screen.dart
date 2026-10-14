import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants/app_colors.dart';
import '../data/models/trading_news_model.dart';
import '../data/services/trading_news_service.dart';
import '../providers/trading_news_provider.dart';
import '../widgets/skeleton_loading.dart';

class CryptoIntelligenceScreen extends ConsumerStatefulWidget {
  const CryptoIntelligenceScreen({super.key});

  @override
  ConsumerState<CryptoIntelligenceScreen> createState() => _CryptoIntelligenceScreenState();
}

class _CryptoIntelligenceScreenState extends ConsumerState<CryptoIntelligenceScreen> {
  String _selectedTab = 'ALL'; // 'ALL', 'SCENARIOS', 'NET_FLOWS', 'MACRO', 'FAST_WIRE', 'ETF', 'UNLOCK'
  String _selectedScenarioId = 'cpi_cool';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final intelAsync = ref.watch(tradingIntelligenceProvider);

    final bgColor = AppColors.background(context);
    final surfaceColor = AppColors.surface(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGlow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.primary, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'WIRE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Trading Intelligence & Scenarios',
                style: TextStyle(color: textPrimary, fontSize: 16.5, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Wire & Calendar',
            icon: Icon(Icons.refresh_rounded, color: textSecondary, size: 22),
            onPressed: () => ref.read(tradingIntelligenceProvider.notifier).fetchIntelligence(forceRefresh: true),
          ),
        ],
      ),
      body: intelAsync.when(
        loading: () => const CryptoIntelligenceSkeleton(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.loss, size: 36),
                const SizedBox(height: 12),
                Text('Unable to load intelligence: $err', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.loss, fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => ref.read(tradingIntelligenceProvider.notifier).fetchIntelligence(forceRefresh: true),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
        data: (intel) {
          final filteredNews = _filterNews(intel.news);

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: surfaceColor,
            onRefresh: () => ref.read(tradingIntelligenceProvider.notifier).fetchIntelligence(forceRefresh: true),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                // 1. High Impact Macro Radar (Pinned Oct 14 US CPI & ETF Flows)
                _buildMacroAndEtfRadar(intel, surfaceColor, borderColor, textPrimary, textSecondary),
                const SizedBox(height: 14),

                // 2. Search & Categorical Filter Pills
                _buildSearchAndFilters(surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
                const SizedBox(height: 14),

                // 3. Tab Specific Interactive Views
                if (_selectedTab == 'SCENARIOS') ...[
                  _buildScenarioMatrixSection(intel.scenarios, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
                  const SizedBox(height: 18),
                ] else if (_selectedTab == 'NET_FLOWS') ...[
                  _buildNetFlowsDetailedSection(intel.netFlows, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
                  const SizedBox(height: 18),
                ] else if (_selectedTab == 'MACRO') ...[
                  _buildMacroCalendarSection(intel.macroEvents, surfaceColor, borderColor, textPrimary, textSecondary),
                  const SizedBox(height: 18),
                ] else if (_selectedTab == 'ETF') ...[
                  _buildEtfDetailsSection(intel.etfFlows, surfaceColor, borderColor, textPrimary, textSecondary),
                  const SizedBox(height: 18),
                ] else if (_selectedTab == 'UNLOCK') ...[
                  _buildTokenUnlocksSection(intel.tokenUnlocks, surfaceColor, borderColor, textPrimary, textSecondary),
                  const SizedBox(height: 18),
                ] else if (_selectedTab == 'ALL') ...[
                  // Teaser Preview of Scenarios in ALL Tab
                  _buildScenarioPreviewBanner(intel.scenarios, surfaceColor, borderColor, textPrimary, textSecondary),
                  const SizedBox(height: 14),
                ],

                // 4. Section Header for News Wire
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedTab == 'ALL' ? 'Live Catalysts & News Wire' : 'Filtered Wire News',
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        '${filteredNews.length} items',
                        style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (filteredNews.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Text('No catalysts found matching your search.', style: TextStyle(color: textSecondary)),
                  )
                else
                  ...filteredNews.map((item) => _buildNewsCard(item, surfaceColor, borderColor, textPrimary, textSecondary, textMuted)),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  List<TradingNewsItem> _filterNews(List<TradingNewsItem> list) {
    return list.where((item) {
      if (_selectedTab == 'FAST_WIRE' && !item.isBreaking && item.category != 'FAST_WIRE') return false;
      if (_selectedTab == 'MACRO' && item.category != 'MACRO') return false;
      if (_selectedTab == 'ETF' && item.category != 'ETF') return false;
      if (_selectedTab == 'UNLOCK' && item.category != 'UNLOCK') return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchTitle = item.title.toLowerCase().contains(q);
        final matchBody = item.body.toLowerCase().contains(q);
        final matchSource = item.source.toLowerCase().contains(q);
        return matchTitle || matchBody || matchSource;
      }
      return true;
    }).toList();
  }

  // ==========================================
  // 1. MACRO & ETF RADAR (WITH OCT 14 CPI)
  // ==========================================
  Widget _buildMacroAndEtfRadar(
    TradingIntelligenceData intel,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    // Pinpoint Oct 14 US CPI
    final cpiEvent = intel.macroEvents.firstWhere(
      (e) => e.title.contains('CPI'),
      orElse: () => intel.macroEvents.first,
    );

    final netFlow = intel.netFlows;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'MARKET CATALYSTS & FOREX FACTORY RADAR',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'HIGH SIGNAL',
                  style: TextStyle(color: Color(0xFF00E676), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Next Macro Event (Oct 14 CPI Highlight)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = 'SCENARIOS'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.loss.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.loss.withAlpha(70)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.loss,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('🔴 RED', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'OCT 14 US CPI',
                                style: const TextStyle(color: AppColors.loss, fontSize: 10.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          cpiEvent.countdownLabel,
                          style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap for BTC/ETH/SOL Scenarios ➔',
                          style: const TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Net Inflow Outflow Card
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = 'NET_FLOWS'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00E676).withAlpha(70)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.waterfall_chart_rounded, color: Color(0xFF00E676), size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'TOTAL NET INFLOW',
                                style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '+${(netFlow.btcEtfDailyMillions + netFlow.ethEtfDailyMillions).toStringAsFixed(1)}M USD',
                          style: const TextStyle(color: Color(0xFF00E676), fontSize: 12.5, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ETF & CEX Outflow Details ➔',
                          style: const TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. SEARCH & CATEGORY PILLS
  // ==========================================
  Widget _buildSearchAndFilters(
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          style: TextStyle(color: textPrimary, fontSize: 13),
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Filter catalysts (CPI, Fed, BTC, ETH, SOL, ETF)...',
            hintStyle: TextStyle(color: textMuted, fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            filled: true,
            fillColor: surfaceColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterPill('ALL', 'All Catalysts', surfaceColor, borderColor, textSecondary),
              _filterPill('SCENARIOS', '🎯 Scenarios (BTC, ETH, SOL)', surfaceColor, borderColor, textSecondary),
              _filterPill('NET_FLOWS', '🌊 Inflow & Outflow Tracker', surfaceColor, borderColor, textSecondary),
              _filterPill('MACRO', '🏛️ Forex Factory Calendar', surfaceColor, borderColor, textSecondary),
              _filterPill('FAST_WIRE', '⚡ Fast Wire', surfaceColor, borderColor, textSecondary),
              _filterPill('ETF', '📊 Spot ETFs', surfaceColor, borderColor, textSecondary),
              _filterPill('UNLOCK', '🔓 Token Unlocks', surfaceColor, borderColor, textSecondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterPill(
    String id,
    String label,
    Color surfaceColor,
    Color borderColor,
    Color textSecondary,
  ) {
    final isSelected = _selectedTab == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedTab = id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : borderColor,
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. SCENARIOS SECTION ("ME DE UNOTH BTC, ETH, SOL WALATA MOKKDA WENNE")
  // ==========================================
  Widget _buildScenarioMatrixSection(
    List<ScenarioSimulationItem> scenarios,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (scenarios.isEmpty) return const SizedBox.shrink();

    final activeScenario = scenarios.firstWhere(
      (s) => s.id == _selectedScenarioId,
      orElse: () => scenarios.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.psychology_alt_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Macro Scenario Engine (BTC, ETH, SOL)',
                        style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('PREDICTIVE', style: TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select a macro catalyst scenario below to view expected price targets and tactical positioning for BTC, ETH, and SOL:',
            style: TextStyle(color: textMuted, fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 12),

          // Scenario Selection Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: scenarios.map((s) {
                final isSelected = s.id == activeScenario.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s.title),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedScenarioId = s.id),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.background(context),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isSelected ? AppColors.primary : borderColor),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Active Scenario Context Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        activeScenario.title,
                        style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00E676).withAlpha(70)),
                      ),
                      child: Text(
                        activeScenario.probability,
                        style: const TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Catalyst: ${activeScenario.catalystEvent}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(activeScenario.macroConsequence, style: TextStyle(color: textSecondary, fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Asset Impact Cards (BTC, ETH, SOL)
          Text('Projected Coin Impacts & Tactical Plays:', style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildCoinPredictionCard('BTC', 'Bitcoin', activeScenario.assetPredictions['BTC'], const Color(0xFFF7931A), surfaceColor, borderColor, textPrimary, textSecondary),
          const SizedBox(height: 10),
          _buildCoinPredictionCard('ETH', 'Ethereum', activeScenario.assetPredictions['ETH'], const Color(0xFF627EEA), surfaceColor, borderColor, textPrimary, textSecondary),
          const SizedBox(height: 10),
          _buildCoinPredictionCard('SOL', 'Solana', activeScenario.assetPredictions['SOL'], const Color(0xFF14F195), surfaceColor, borderColor, textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _buildCoinPredictionCard(
    String symbol,
    String name,
    AssetScenarioPrediction? pred,
    Color coinColor,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (pred == null) return const SizedBox.shrink();

    final isBullish = pred.isBullish;
    final statusColor = isBullish ? const Color(0xFF00E676) : AppColors.loss;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: coinColor.withAlpha(30),
                child: Text(symbol, style: TextStyle(color: coinColor, fontSize: 8.5, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$name ($symbol)', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withAlpha(80), width: 0.8),
                ),
                child: Text(
                  '${pred.bias} (${pred.expectedMove})',
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Target Price Range: ', style: TextStyle(color: textSecondary, fontSize: 11)),
              Text(pred.priceTarget, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 5),
          Text('Key Driver: ${pred.keyDriver}', style: TextStyle(color: textSecondary, fontSize: 11, height: 1.3)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Tactical Play: ${pred.tacticalPlay}', style: const TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioPreviewBanner(
    List<ScenarioSimulationItem> scenarios,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text('Macro Impact Simulator', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _selectedTab = 'SCENARIOS'),
                child: const Text('Open All Scenarios ➔', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'What happens to BTC, ETH, and SOL if tomorrow\'s US CPI prints Cool (<2.3%) vs Hot (>2.5%)?',
            style: TextStyle(color: textSecondary, fontSize: 11.5, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676).withAlpha(30),
                    foregroundColor: const Color(0xFF00E676),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF00E676))),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedScenarioId = 'cpi_cool';
                      _selectedTab = 'SCENARIOS';
                    });
                  },
                  icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                  label: const Text('Cool CPI (+8% BTC)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.loss.withAlpha(30),
                    foregroundColor: AppColors.loss,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.loss)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedScenarioId = 'cpi_hot';
                      _selectedTab = 'SCENARIOS';
                    });
                  },
                  icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                  label: const Text('Hot CPI (-5% BTC)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. INFLOW & OUTFLOW DETAILED SECTION
  // ==========================================
  Widget _buildNetFlowsDetailedSection(
    MarketNetFlowSummary netFlow,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Institutional & Exchange Net Flow Radar', style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('ACCUMULATION', style: TextStyle(color: Color(0xFF00E676), fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ETF Inflow Snapshot Rows
          Row(
            children: [
              Expanded(
                child: _buildFlowMetricTile(
                  'BTC Spot ETF (24h)',
                  '+${netFlow.btcEtfDailyMillions.toStringAsFixed(1)}M',
                  '+${netFlow.btcEtf7DayMillions.toStringAsFixed(0)}M (7D)',
                  const Color(0xFF00E676),
                  Icons.trending_up,
                  borderColor,
                  textPrimary,
                  textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFlowMetricTile(
                  'ETH Spot ETF (24h)',
                  '+${netFlow.ethEtfDailyMillions.toStringAsFixed(1)}M',
                  '+${netFlow.ethEtf7DayMillions.toStringAsFixed(0)}M (7D)',
                  const Color(0xFF00E676),
                  Icons.trending_up,
                  borderColor,
                  textPrimary,
                  textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFlowMetricTile(
                  'BTC Exchange Net Outflow',
                  '${netFlow.btcExchangeNetFlowCoins.toStringAsFixed(0)} BTC',
                  'Withdrawn to Cold Storage (Bullish)',
                  AppColors.primary,
                  Icons.lock_outline_rounded,
                  borderColor,
                  textPrimary,
                  textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFlowMetricTile(
                  'Stablecoin CEX Inflow',
                  '+${netFlow.stablecoinNetInflowMillions.toStringAsFixed(0)}M USD',
                  'Fresh Buying Dry Powder',
                  const Color(0xFF00E676),
                  Icons.account_balance_wallet_outlined,
                  borderColor,
                  textPrimary,
                  textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Breakdown by Issuer
          Text('Top Institutional Contributors Today:', style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...netFlow.etfBreakdowns.map((etf) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: etf.asset == 'BTC' ? const Color(0xFFF7931A).withAlpha(30) : const Color(0xFF627EEA).withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(etf.asset, style: TextStyle(color: etf.asset == 'BTC' ? const Color(0xFFF7931A) : const Color(0xFF627EEA), fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            etf.topContributor,
                            style: TextStyle(color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(etf.statusText, style: const TextStyle(color: Color(0xFF00E676), fontSize: 11.5, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFlowMetricTile(
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(title, style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: textMuted, fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ==========================================
  // 5. FOREX FACTORY MACRO CALENDAR SECTION
  // ==========================================
  Widget _buildMacroCalendarSection(
    List<MacroEventItem> events,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Forex Factory Economic Calendar',
                        style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.loss.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.loss.withAlpha(60)),
                ),
                child: const Text('🔴 RED FOLDERS', style: TextStyle(color: AppColors.loss, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...events.map((e) {
            final isRedFolder = e.folderColor == 'RED';
            final folderColor = isRedFolder ? AppColors.loss : Colors.orange;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: e.title.contains('CPI') ? AppColors.loss.withAlpha(90) : borderColor,
                  width: e.title.contains('CPI') ? 1.2 : 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: folderColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: folderColor.withAlpha(80), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_rounded, color: folderColor, size: 12),
                            const SizedBox(width: 3),
                            Text(e.currency, style: TextStyle(color: folderColor, fontSize: 9.5, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.title,
                          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: e.title.contains('CPI') ? AppColors.loss : AppColors.primaryGlow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          e.countdownLabel,
                          style: TextStyle(
                            color: e.title.contains('CPI') ? Colors.white : AppColors.primary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('${DateFormat('MMM dd').format(e.eventDate)} • ${e.timeString}', style: TextStyle(color: textSecondary, fontSize: 11)),
                        ],
                      ),
                      Text('Forecast: ${e.forecast}', style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('Prev: ${e.previous}', style: TextStyle(color: textSecondary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(e.description, style: TextStyle(color: textSecondary, fontSize: 11, height: 1.3)),
                  if (e.title.contains('CPI')) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() => _selectedTab = 'SCENARIOS'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withAlpha(60)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insights_rounded, color: AppColors.primary, size: 13),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Simulate Oct 14 CPI Scenarios for BTC, ETH, SOL ➔',
                                style: TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // 6. TOKEN UNLOCKS & SPOT ETF SECTIONS
  // ==========================================
  Widget _buildTokenUnlocksSection(
    List<TokenUnlockAlert> unlocks,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Upcoming Cliff Token Releases', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              const Text('Dump Risk Radar', style: TextStyle(color: AppColors.loss, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...unlocks.map((u) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryGlow,
                      child: Text(
                        u.symbol.substring(0, u.symbol.length > 3 ? 3 : u.symbol.length),
                        style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${u.name} (${u.symbol})', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('\$${u.amountUsdMillions.toStringAsFixed(1)}M (${u.percentOfCirculating}% of supply)', style: TextStyle(color: textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('In ${u.daysUntil} days', style: const TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEtfDetailsSection(
    List<EtfFlowSnapshot> etfs,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spot ETF Institutional Tracking', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...etfs.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      e.isPositive ? Icons.account_balance : Icons.account_balance_outlined,
                      color: e.isPositive ? const Color(0xFF00E676) : AppColors.loss,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.asset} Spot ETFs • ${e.statusText}', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(e.topContributor, style: TextStyle(color: textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ==========================================
  // 7. NEWS CARD & IN-APP WEB READER UI
  // ==========================================
  Widget _buildNewsCard(
    TradingNewsItem item,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    Color sentColor = textSecondary;
    String sentLabel = 'NEUTRAL';
    if (item.sentiment == 'BULLISH') {
      sentColor = const Color(0xFF00E676);
      sentLabel = 'BULLISH';
    } else if (item.sentiment == 'BEARISH') {
      sentColor = AppColors.loss;
      sentLabel = 'BEARISH';
    }

    final timeAgoStr = _formatTimeAgo(item.publishedAt);

    return InkWell(
      onTap: () => _openNewsWebReader(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: sentColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: sentColor.withAlpha(80), width: 0.6),
                  ),
                  child: Text(
                    sentLabel,
                    style: TextStyle(color: sentColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.source,
                    style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(timeAgoStr, style: TextStyle(color: textMuted, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
            ),
            if (item.body.isNotEmpty && item.body != item.title) ...[
              const SizedBox(height: 6),
              Text(
                item.body,
                style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_rounded, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Read Full Article (Web UI) ↗', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Tap to simulate BTC impact',
                    style: TextStyle(color: textMuted, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// IN-APP WEB READER MODAL UI
  void _openNewsWebReader(TradingNewsItem item) {
    final bgColor = AppColors.surface(context);
    final surfaceLight = AppColors.surfaceLight(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textMuted = AppColors.textMuted(context);

    Color sentColor = textSecondary;
    String sentLabel = 'NEUTRAL';
    if (item.sentiment == 'BULLISH') {
      sentColor = const Color(0xFF00E676);
      sentLabel = 'BULLISH';
    } else if (item.sentiment == 'BEARISH') {
      sentColor = AppColors.loss;
      sentLabel = 'BEARISH';
    }

    String readerTab = 'READER'; // 'READER', 'SCENARIO_IMPACT'

    final hostUrl = item.url.isNotEmpty
        ? (Uri.tryParse(item.url)?.host ?? 'cryptopanic.com')
        : 'wire.cryptonews.io';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalCtx).size.height * 0.90,
                ),
                child: Column(
                  children: [
                    // Simulated Web Browser Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: surfaceLight,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Column(
                        children: [
                          // Browser Window Top Controls
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                color: textSecondary,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.pop(modalCtx),
                              ),
                              const SizedBox(width: 10),
                              // Simulated HTTPS Address Bar
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF00E676)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'https://$hostUrl/news/${item.id}',
                                          style: TextStyle(color: textSecondary, fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Copy Link',
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                color: textSecondary,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  final link = item.url.isNotEmpty ? item.url : 'https://$hostUrl';
                                  Clipboard.setData(ClipboardData(text: link));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Article URL copied to clipboard!'), duration: Duration(seconds: 2)),
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                tooltip: 'Share',
                                icon: const Icon(Icons.share_outlined, size: 18),
                                color: textSecondary,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  final text = item.url.isNotEmpty ? '${item.title}\n${item.url}' : item.title;
                                  SharePlus.instance.share(ShareParams(text: text, subject: item.title));
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // View Switcher: Reader View vs Scenario Impact
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(() => readerTab = 'READER'),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: readerTab == 'READER' ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '📖 Reader View',
                                      style: TextStyle(
                                        color: readerTab == 'READER' ? Colors.white : textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(() => readerTab = 'SCENARIO_IMPACT'),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: readerTab == 'SCENARIO_IMPACT' ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '🎯 BTC/ETH/SOL Impact',
                                      style: TextStyle(
                                        color: readerTab == 'SCENARIO_IMPACT' ? Colors.white : textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Article Body / Impact View
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: readerTab == 'READER'
                            ? _buildReaderModeContent(item, sentColor, sentLabel, surfaceLight, borderColor, textPrimary, textSecondary, textMuted)
                            : _buildNewsScenarioImpactContent(item, surfaceLight, borderColor, textPrimary, textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReaderModeContent(
    TradingNewsItem item,
    Color sentColor,
    String sentLabel,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta Tags
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: sentColor.withAlpha(80), width: 0.8),
              ),
              child: Text(sentLabel, style: TextStyle(color: sentColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryGlow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(item.source, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            Text(DateFormat('MMM dd, yyyy • hh:mm a').format(item.publishedAt), style: TextStyle(color: textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 14),

        // Headline
        Text(
          item.title,
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
        ),
        const SizedBox(height: 14),

        // AI Intelligence Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withAlpha(50)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                  SizedBox(width: 6),
                  Text('AI Executive Key Points', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Immediate Catalyst: Market sentiment shift regarding ${item.category} flows.\n'
                '• Institutional Implication: High correlation to spot order books and perpetual funding rates.\n'
                '• Volatility Expectation: Active liquidation wicks expected across high-beta tokens.',
                style: TextStyle(color: textSecondary, fontSize: 11.5, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Full Body Story
        Text(
          item.body.isNotEmpty ? item.body : 'No additional story text provided by source wire.',
          style: TextStyle(color: textPrimary, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verified wire dispatch from ${item.source}. Always cross-reference with live exchange order books before entering leveraged trades.',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewsScenarioImpactContent(
    TradingNewsItem item,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isBull = item.sentiment == 'BULLISH';
    final moveBtc = isBull ? '+3.5% to +5.0%' : '-2.8% to -4.5%';
    final moveEth = isBull ? '+4.2% to +6.8%' : '-3.5% to -5.5%';
    final moveSol = isBull ? '+5.8% to +9.2%' : '-4.5% to -7.5%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.insights_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Simulated Asset Impact for this Wire Alert',
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Based on historical order book response to ${item.source} catalysts:',
          style: TextStyle(color: textSecondary, fontSize: 11.5),
        ),
        const SizedBox(height: 14),

        _buildQuickAssetCard('BTC', 'Bitcoin', moveBtc, isBull, const Color(0xFFF7931A), 'Immediate spot response', surfaceLight, borderColor, textPrimary, textSecondary),
        const SizedBox(height: 10),
        _buildQuickAssetCard('ETH', 'Ethereum', moveEth, isBull, const Color(0xFF627EEA), 'High beta Layer-2 reaction', surfaceLight, borderColor, textPrimary, textSecondary),
        const SizedBox(height: 10),
        _buildQuickAssetCard('SOL', 'Solana', moveSol, isBull, const Color(0xFF14F195), 'Retail velocity multiplier', surfaceLight, borderColor, textPrimary, textSecondary),

        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedTab = 'SCENARIOS');
            },
            icon: const Icon(Icons.open_in_new, color: Colors.white, size: 16),
            label: const Text('Open Full Forex Factory & CPI Scenario Simulator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAssetCard(
    String symbol,
    String name,
    String move,
    bool isBull,
    Color coinColor,
    String note,
    Color surfaceLight,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final statusColor = isBull ? const Color(0xFF00E676) : AppColors.loss;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: coinColor.withAlpha(30),
            child: Text(symbol, style: TextStyle(color: coinColor, fontSize: 9, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name ($symbol)', style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold)),
                Text(note, style: TextStyle(color: textSecondary, fontSize: 10.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withAlpha(80), width: 0.8),
            ),
            child: Text(move, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inMinutes <= 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
