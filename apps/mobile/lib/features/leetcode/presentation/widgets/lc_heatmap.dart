import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// 90-day solve activity heatmap.
class LCHeatmap extends StatelessWidget {
  const LCHeatmap({super.key, required this.data});

  /// Map of "YYYY-MM-DD" -> solve count.
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final days = _buildDays();
    final weeks = <List<_Day>>[];
    for (var i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: weeks.map((week) {
              return Column(
                children: week.map((day) {
                  return _HeatCell(day: day);
                }).toList(),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Legend(),
      ],
    );
  }

  List<_Day> _buildDays() {
    final now = DateTime.now();
    final days = <_Day>[];
    for (var i = 89; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      days.add(_Day(date: d, count: data[key] ?? 0));
    }
    return days;
  }
}

class _Day {
  const _Day({required this.date, required this.count});
  final DateTime date;
  final int count;
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.day});
  final _Day day;

  Color get _color {
    if (day.count == 0) return AppColors.surfaceContainer;
    if (day.count == 1) return AppColors.primary.withValues(alpha: 0.25);
    if (day.count == 2) return AppColors.primary.withValues(alpha: 0.50);
    if (day.count <= 4) return AppColors.primary.withValues(alpha: 0.75);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${day.count} solve${day.count != 1 ? 's' : ''} · ${day.date.month}/${day.date.day}',
      child: Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: _color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('LESS', style: AppTypography.tacticalLabel(fontSize: 7, color: AppColors.onSurfaceDim)),
        const SizedBox(width: 4),
        ...[0.0, 0.25, 0.5, 0.75, 1.0].map((a) => Container(
              width: 10, height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: a == 0
                    ? AppColors.surfaceContainer
                    : AppColors.primary.withValues(alpha: a),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
        const SizedBox(width: 4),
        Text('MORE', style: AppTypography.tacticalLabel(fontSize: 7, color: AppColors.onSurfaceDim)),
      ],
    );
  }
}
