import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

enum BadgeSize { small, medium, large }

/// Tactical rank badge widget.
class LCRankBadge extends StatelessWidget {
  const LCRankBadge({super.key, required this.rank, this.size = BadgeSize.medium});

  final String rank;
  final BadgeSize size;

  static const _rankMeta = {
    'INITIATE':   _RankMeta(label: 'INIT', color: Color(0xFF6E6E78)),
    'OPERATOR':   _RankMeta(label: 'OPR', color: Color(0xFF6EC8D4)),
    'SPECIALIST': _RankMeta(label: 'SPEC', color: Color(0xFF4BA8B4)),
    'ELITE':      _RankMeta(label: 'ELITE', color: Color(0xFFD4A843)),
    'TITAN':      _RankMeta(label: 'TTN', color: Color(0xFFC4642A)),
    'APEX':       _RankMeta(label: 'APEX', color: Color(0xFFB44FD4)),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _rankMeta[rank] ?? _rankMeta['INITIATE']!;

    final fontSize = switch (size) {
      BadgeSize.small => 7.0,
      BadgeSize.medium => 9.0,
      BadgeSize.large => 11.0,
    };
    final hPad = switch (size) {
      BadgeSize.small => 4.0,
      BadgeSize.medium => 6.0,
      BadgeSize.large => 10.0,
    };
    final vPad = switch (size) {
      BadgeSize.small => 1.0,
      BadgeSize.medium => 2.0,
      BadgeSize.large => 4.0,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: meta.color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        meta.label,
        style: AppTypography.tacticalLabel(fontSize: fontSize, color: meta.color),
      ),
    );
  }
}

class _RankMeta {
  const _RankMeta({required this.label, required this.color});
  final String label;
  final Color color;
}
