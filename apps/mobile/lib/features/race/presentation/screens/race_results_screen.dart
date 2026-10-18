import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/lc_app_bar.dart';

class RaceResultsScreen extends StatelessWidget {
  const RaceResultsScreen({super.key, required this.results});

  final List<Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) {
    final sorted = [...results]..sort((a, b) {
        final ra = a['placement'] as int? ?? 99;
        final rb = b['placement'] as int? ?? 99;
        return ra.compareTo(rb);
      });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Race Results'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text('FINAL RESULTS', style: AppTypography.tacticalLabel(color: AppColors.primary)),
            const SizedBox(height: AppSpacing.sectionGap),

            ...sorted.map((r) {
              final placement = r['placement'] as int? ?? 0;
              final name = r['displayName'] as String? ?? '—';
              final ms = r['durationMs'] as int? ?? 0;
              final status = r['status'] as String? ?? '—';
              final isAccepted = status == 'ACCEPTED';

              final placeColor = switch (placement) {
                1 => const Color(0xFFD4A843),
                2 => const Color(0xFFB0B0B8),
                3 => const Color(0xFFA0714F),
                _ => AppColors.onSurfaceDim,
              };

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: placement == 1
                      ? placeColor.withValues(alpha: 0.07)
                      : AppColors.surfaceVariant,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(
                    color: placement <= 3 ? placeColor.withValues(alpha: 0.2) : AppColors.surfaceBorder,
                    width: placement == 1 ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '#$placement',
                        style: AppTypography.stat(fontSize: 18, color: placeColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: Theme.of(context).textTheme.titleSmall),
                          if (isAccepted)
                            Row(
                              children: [
                                const Icon(PhosphorIconsBold.checkCircle, size: 10, color: AppColors.success),
                                const SizedBox(width: 4),
                                Text(
                                  'ACCEPTED · ${_formatMs(ms)}',
                                  style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.success),
                                ),
                              ],
                            )
                          else
                            Text(status, style: AppTypography.tacticalLabel(fontSize: 8, color: AppColors.onSurfaceDim)),
                        ],
                      ),
                    ),
                    if (placement == 1)
                      const Icon(PhosphorIconsBold.trophy, size: 20, color: Color(0xFFD4A843)),
                  ],
                ),
              );
            }),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/races'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('BACK TO HOME',
                    style: AppTypography.tacticalLabel(color: AppColors.onSurfaceMedium)),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${sec}s';
  }
}
