import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_shimmer.dart';

// ── Models ─────────────────────────────────────────────────────────

class SolveAnalytics {
  const SolveAnalytics({
    this.totalSolves = 0,
    this.byDifficulty = const _Difficulty(),
    this.byLanguage = const {},
    this.topTopics = const [],
    this.weakTopics = const [],
    this.recentTrend = const [],
    this.avgSolveHour = 20,
  });

  final int totalSolves;
  final _Difficulty byDifficulty;
  final Map<String, int> byLanguage;
  final List<_Topic> topTopics;
  final List<_Topic> weakTopics;
  final List<_TrendPoint> recentTrend;
  final int avgSolveHour;

  factory SolveAnalytics.fromJson(Map<String, dynamic> j) {
    return SolveAnalytics(
      totalSolves: j['totalSolves'] ?? 0,
      byDifficulty: _Difficulty.fromJson(j['byDifficulty'] ?? {}),
      byLanguage: Map<String, int>.from(j['byLanguage'] ?? {}),
      topTopics: (j['topTopics'] as List? ?? []).map((e) => _Topic.fromJson(e)).toList(),
      weakTopics: (j['weakTopics'] as List? ?? []).map((e) => _Topic.fromJson(e)).toList(),
      recentTrend: (j['recentTrend'] as List? ?? []).map((e) => _TrendPoint.fromJson(e)).toList(),
      avgSolveHour: j['avgSolveHour'] ?? 20,
    );
  }
}

class _Difficulty {
  const _Difficulty({this.easy = 0, this.medium = 0, this.hard = 0});
  final int easy;
  final int medium;
  final int hard;
  int get total => easy + medium + hard;
  factory _Difficulty.fromJson(Map<String, dynamic> j) =>
      _Difficulty(easy: j['easy'] ?? 0, medium: j['medium'] ?? 0, hard: j['hard'] ?? 0);
}

class _Topic { const _Topic({required this.tag, required this.count});
  final String tag; final int count;
  factory _Topic.fromJson(Map<String, dynamic> j) => _Topic(tag: j['tag'] ?? '', count: j['count'] ?? 0);
}

class _TrendPoint { const _TrendPoint({required this.date, required this.count});
  final String date; final int count;
  factory _TrendPoint.fromJson(Map<String, dynamic> j) => _TrendPoint(date: j['date'] ?? '', count: j['count'] ?? 0);
}

class Insight { const Insight({required this.id, required this.type, required this.title, required this.body, this.metric});
  final String id; final String type; final String title; final String body; final String? metric;
  factory Insight.fromJson(Map<String, dynamic> j) => Insight(id: j['id'] ?? '', type: j['type'] ?? '', title: j['title'] ?? '', body: j['body'] ?? '', metric: j['metric']);
}

// ── Screen ─────────────────────────────────────────────────────────

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends ConsumerState<AnalyticsDashboardScreen> {
  SolveAnalytics? _analytics;
  List<Insight> _insights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final [analyticsRes, insightsRes] = await Future.wait([
      api.get('/analytics'),
      api.get('/analytics/insights'),
    ]);
    if (!mounted) return;
    setState(() {
      _analytics = SolveAnalytics.fromJson(analyticsRes.data['data']);
      _insights = (insightsRes.data['data'] as List? ?? []).map((e) => Insight.fromJson(e)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(backgroundColor: AppColors.surface, appBar: const LCAppBar(title: 'Analytics'), body: const LCShimmer(itemCount: 6));

    final a = _analytics!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'Analytics',
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.arrowsClockwise, size: 16),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            // ── Difficulty breakdown bar ─────────────────────
            _SectionLabel('DIFFICULTY BREAKDOWN'),
            _DifficultyBar(d: a.byDifficulty),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Activity trend ───────────────────────────────
            _SectionLabel('30-DAY ACTIVITY'),
            _TrendChart(points: a.recentTrend),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Language breakdown ───────────────────────────
            if (a.byLanguage.isNotEmpty) ...[
              _SectionLabel('LANGUAGES'),
              _LanguageBreakdown(langs: a.byLanguage, total: a.totalSolves),
              const SizedBox(height: AppSpacing.sectionGap),
            ],

            // ── Top topics ───────────────────────────────────
            if (a.topTopics.isNotEmpty) ...[
              _SectionLabel('TOP TOPICS'),
              ...a.topTopics.map((t) => _TopicBar(topic: t, max: a.topTopics.first.count, color: AppColors.primary)),
              const SizedBox(height: AppSpacing.sectionGap),
            ],

            // ── Insights ─────────────────────────────────────
            if (_insights.isNotEmpty) ...[
              _SectionLabel('INSIGHTS'),
              ..._insights.map((i) => _InsightCard(insight: i)),
            ],

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(label, style: AppTypography.tacticalLabel()),
  );
}

class _DifficultyBar extends StatelessWidget {
  const _DifficultyBar({required this.d});
  final _Difficulty d;

  @override
  Widget build(BuildContext context) {
    final total = d.total;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.cardRadius),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatPill(label: 'EASY', value: '${d.easy}', color: AppColors.easy),
              _StatPill(label: 'MEDIUM', value: '${d.medium}', color: AppColors.medium),
              _StatPill(label: 'HARD', value: '${d.hard}', color: AppColors.hard),
              _StatPill(label: 'TOTAL', value: '$total', color: AppColors.onSurfaceMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Row(children: [
                if (d.easy > 0) Flexible(flex: d.easy, child: Container(height: 6, color: AppColors.easy)),
                if (d.medium > 0) Flexible(flex: d.medium, child: Container(height: 6, color: AppColors.medium)),
                if (d.hard > 0) Flexible(flex: d.hard, child: Container(height: 6, color: AppColors.hard)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.color});
  final String label; final String value; final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: AppTypography.stat(fontSize: 18, color: color)),
    Text(label, style: AppTypography.tacticalLabel(fontSize: 7)),
  ]);
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});
  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final max = points.map((p) => p.count).fold(1, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.cardRadius),
      child: SizedBox(
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: points.map((p) {
            final frac = max > 0 ? p.count / max : 0.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Tooltip(
                  message: '${p.count} on ${p.date}',
                  child: Container(
                    height: 60 * frac.clamp(0.04, 1.0),
                    decoration: BoxDecoration(
                      color: p.count > 0
                          ? AppColors.primary.withValues(alpha: 0.3 + frac * 0.7)
                          : AppColors.surfaceContainer,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _LanguageBreakdown extends StatelessWidget {
  const _LanguageBreakdown({required this.langs, required this.total});
  final Map<String, int> langs; final int total;

  @override
  Widget build(BuildContext context) {
    final sorted = langs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.cardRadius),
      child: Column(
        children: sorted.take(5).map((e) {
          final frac = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 80, child: Text(e.key.toUpperCase(), style: AppTypography.tacticalLabel(fontSize: 8))),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: frac, backgroundColor: AppColors.surfaceContainer, valueColor: const AlwaysStoppedAnimation(AppColors.secondary), minHeight: 4),
              )),
              const SizedBox(width: 8),
              Text('${(frac * 100).round()}%', style: AppTypography.tacticalLabel(fontSize: 7, color: AppColors.onSurfaceDim)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _TopicBar extends StatelessWidget {
  const _TopicBar({required this.topic, required this.max, required this.color});
  final _Topic topic; final int max; final Color color;

  @override
  Widget build(BuildContext context) {
    final frac = max > 0 ? topic.count / max : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 120, child: Text(topic.tag.replaceAll('-', ' ').toUpperCase(), style: AppTypography.tacticalLabel(fontSize: 8), overflow: TextOverflow.ellipsis)),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: frac, backgroundColor: AppColors.surfaceContainer, valueColor: AlwaysStoppedAnimation(color), minHeight: 4))),
        const SizedBox(width: 8),
        Text('${topic.count}', style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.onSurfaceDim)),
      ]),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final Insight insight;

  Color get _accent {
    switch (insight.type) {
      case 'strength': return AppColors.success;
      case 'weakness': return AppColors.error;
      case 'recommendation': return AppColors.warning;
      default: return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.cardRadius,
        border: Border(left: BorderSide(color: _accent, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(insight.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: _accent)),
              const SizedBox(height: 4),
              Text(insight.body, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMedium, height: 1.5)),
            ],
          )),
          if (insight.metric != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(insight.metric!, style: AppTypography.stat(fontSize: 11, color: _accent)),
          ],
        ],
      ),
    );
  }
}
