import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_button.dart';

/// Solve race lobby — create or join a race room.
class RaceLobbyScreen extends ConsumerStatefulWidget {
  const RaceLobbyScreen({super.key});

  @override
  ConsumerState<RaceLobbyScreen> createState() => _RaceLobbyScreenState();
}

class _RaceLobbyScreenState extends ConsumerState<RaceLobbyScreen> {
  final _codeCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final slug = _slugCtrl.text.trim();
    if (slug.isEmpty) return;
    setState(() { _isCreating = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/races', data: { 'problemSlug': slug });
      final room = res.data['data'];
      if (!mounted) return;
      context.pushReplacement('/races/${room['id']}?host=1');
    } catch (e) {
      setState(() => _error = 'Failed to create room');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _isJoining = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/races/join', data: { 'code': code });
      final room = res.data['data'];
      if (!mounted) return;
      context.pushReplacement('/races/${room['id']}');
    } catch (e) {
      setState(() => _error = 'Room not found or already started');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Solve Race'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),

            // ── Create section ─────────────────────────────────
            _SectionHeader(icon: PhosphorIconsBold.plus, label: 'Create room'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _slugCtrl,
              decoration: const InputDecoration(
                hintText: 'Problem slug (e.g. two-sum)',
                prefixIcon: Icon(PhosphorIconsBold.code, size: 16),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: LCButton(
                label: 'Create race room',
                icon: PhosphorIconsBold.flagCheckered,
                isLoading: _isCreating,
                isExpanded: true,
                onPressed: _createRoom,
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),
            const Divider(color: AppColors.surfaceBorder),
            const SizedBox(height: AppSpacing.xxxl),

            // ── Join section ───────────────────────────────────
            _SectionHeader(icon: PhosphorIconsBold.signIn, label: 'Join room'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.stat(fontSize: 20, color: AppColors.primary),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: 'Room code',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: LCButton(
                label: 'Join room',
                icon: PhosphorIconsBold.arrowRight,
                isLoading: _isJoining,
                isExpanded: true,
                onPressed: _joinRoom,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: AppTypography.tacticalLabel(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTypography.tacticalLabel(color: AppColors.primary)),
      ],
    );
  }
}
