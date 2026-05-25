import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_stat_container.dart';
import '../../../../shared/widgets/lc_streak_indicator.dart';
import '../../../../shared/widgets/lc_progress_bar.dart';
import '../../../../shared/widgets/lc_metallic_container.dart';
import '../../../../shared/widgets/lc_status_badge.dart';
import '../../../../shared/widgets/lc_shimmer.dart';
import '../../../../shared/widgets/lc_toast.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../leetcode/providers/leetcode_provider.dart';
import '../../../gamification/providers/gamification_provider.dart';

/// Profile screen — live user stats from API.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(leetcodeProvider.notifier).loadAll();
      ref.read(gamificationProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final lc = ref.watch(leetcodeProvider);
    final gami = ref.watch(gamificationProvider);

    final stats = lc.stats;
    final progression = gami.progression;
    final displayName = auth.displayName ?? 'OPERATIVE';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    final total = stats.totalSolves;
    final easy = stats.easySolves;
    final medium = stats.mediumSolves;
    final hard = stats.hardSolves;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'Profile',
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.gear, size: 20),
            onPressed: () {},
            color: AppColors.onSurfaceMedium,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        onRefresh: () async {
          await Future.wait([
            ref.read(leetcodeProvider.notifier).loadAll(),
            ref.read(gamificationProvider.notifier).loadAll(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              // ── Avatar & name ───────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceContainer,
                        border: Border.all(
                          color: AppColors.metallic.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: AppTypography.stat(
                            fontSize: 28,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    const LCStatusBadge(status: UserStatusType.online),
                    const SizedBox(height: 6),
                    // LeetCode handle
                    if (lc.linkStatus.leetcodeUsername != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsBold.code,
                            size: 10,
                            color: lc.linkStatus.isVerified
                                ? AppColors.success
                                : AppColors.onSurfaceDim,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lc.linkStatus.leetcodeUsername!,
                            style: AppTypography.tacticalLabel(
                              fontSize: 9,
                              color: lc.linkStatus.isVerified
                                  ? AppColors.success
                                  : AppColors.onSurfaceDim,
                            ),
                          ),
                          if (lc.linkStatus.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                PhosphorIconsBold.sealCheck,
                                size: 10,
                                color: AppColors.success,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Progression bar ─────────────────────────────
              LCMetallicContainer(
                intensity: MetallicIntensity.subtle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 0.5),
                          ),
                          child: Text(
                            progression.rank,
                            style: AppTypography.tacticalLabel(
                              color: AppColors.primary,
                              fontSize: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'LVL ${progression.level}',
                          style: AppTypography.stat(
                              fontSize: 14, color: AppColors.onSurface),
                        ),
                        const Spacer(),
                        Text(
                          '${progression.xp} XP',
                          style: AppTypography.stat(
                              fontSize: 12, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LCProgressBar(progress: progression.progress, height: 5, showGlow: true),
                    const SizedBox(height: 6),
                    Text(
                      progression.nextRank != null
                          ? '${progression.currentLevelXP} / ${progression.nextLevelXP} XP → ${progression.nextRank}'
                          : 'MAX RANK ACHIEVED',
                      style: AppTypography.tacticalLabel(
                          fontSize: 8, color: AppColors.onSurfaceDim),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Stats grid ──────────────────────────────────
              if (lc.isLoading && total == 0)
                const LCShimmer(itemCount: 2)
              else ...[
                Row(
                  children: [
                    Expanded(
                        child: LCStatContainer(
                            label: 'SOLVED',
                            value: '$total',
                            valueColor: AppColors.success)),
                    const SizedBox(width: AppSpacing.itemGap),
                    Expanded(
                        child: LCStatContainer(
                            label: 'XP',
                            value: '${progression.xp}',
                            valueColor: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.itemGap),
                Row(
                  children: [
                    Expanded(
                        child: LCStatContainer(
                            label: 'STREAK',
                            value: '${stats.streak.currentStreak}d')),
                    const SizedBox(width: AppSpacing.itemGap),
                    Expanded(
                        child: LCStreakIndicator(
                      currentStreak: stats.streak.currentStreak,
                      longestStreak: stats.streak.longestStreak,
                    )),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Difficulty breakdown ────────────────────────
              LCMetallicContainer(
                intensity: MetallicIntensity.subtle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DIFFICULTY BREAKDOWN', style: AppTypography.tacticalLabel()),
                    const SizedBox(height: AppSpacing.lg),
                    _DifficultyRow(label: 'EASY', count: easy, total: total, color: AppColors.easy),
                    const SizedBox(height: AppSpacing.md),
                    _DifficultyRow(
                        label: 'MEDIUM', count: medium, total: total, color: AppColors.medium),
                    const SizedBox(height: AppSpacing.md),
                    _DifficultyRow(label: 'HARD', count: hard, total: total, color: AppColors.hard),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Extension token ─────────────────────────────
              _ExtensionTokenCard(storage: ref.read(secureStorageProvider)),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Sign out ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ref.read(authStateProvider.notifier).signOut(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error, width: 0.5),
                    foregroundColor: AppColors.error,
                  ),
                  child: Text(
                    'SIGN OUT',
                    style: AppTypography.tacticalLabel(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Extension Token Card ─────────────────────────────────────────────────────

class _ExtensionTokenCard extends StatefulWidget {
  const _ExtensionTokenCard({required this.storage});
  final SecureStorage storage;

  @override
  State<_ExtensionTokenCard> createState() => _ExtensionTokenCardState();
}

class _ExtensionTokenCardState extends State<_ExtensionTokenCard> {
  bool _copied = false;

  Future<void> _copyToken() async {
    final token = await widget.storage.getAccessToken();
    if (token == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: token));
    setState(() => _copied = true);
    if (mounted) {
      LCToastManager.show(
        context,
        title: 'Token copied',
        subtitle: 'Paste it into the mitaLeet Chrome extension',
        accentColor: AppColors.primary,
      );
    }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return LCMetallicContainer(
      intensity: MetallicIntensity.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsBold.puzzlePiece,
                  size: 12, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('EXTENSION TOKEN',
                  style: AppTypography.tacticalLabel(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Copy your API token and paste it into the mitaLeet Chrome extension to enable real-time solve tracking.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMedium,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: _copyToken,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpX...',
                      style: AppTypography.tacticalLabel(
                        fontSize: 9,
                        color: AppColors.onSurfaceDim,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    _copied
                        ? PhosphorIconsBold.checkCircle
                        : PhosphorIconsBold.copy,
                    size: 16,
                    color:
                        _copied ? AppColors.success : AppColors.onSurfaceMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Difficulty Row ────────────────────────────────────────────────────────────

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: AppTypography.tacticalLabel(fontSize: 9, color: color)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: LCProgressBar(
            progress: total > 0 ? count / total : 0,
            height: 4,
            color: color,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            style: AppTypography.stat(fontSize: 12, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
