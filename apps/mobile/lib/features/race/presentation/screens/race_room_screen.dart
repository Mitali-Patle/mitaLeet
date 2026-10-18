import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/socket/socket_events.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_button.dart';
import '../../../../shared/widgets/lc_toast.dart';

class RaceRoomScreen extends ConsumerStatefulWidget {
  const RaceRoomScreen({super.key, required this.roomId, required this.isCreator});
  final String roomId;
  final bool isCreator;

  @override
  ConsumerState<RaceRoomScreen> createState() => _RaceRoomScreenState();
}

class _RaceRoomScreenState extends ConsumerState<RaceRoomScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _room;
  String _myStatus = 'WAITING';
  int _countdown = 0;
  Timer? _countdownTimer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  bool _raceStarted = false;
  bool _isSubmitting = false;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: AppAnimations.pulse)
      ..repeat(reverse: true);
    _loadRoom();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    _pulseCtrl.dispose();
    final socket = ref.read(socketServiceProvider);
    socket.off(SocketEvents.raceCountdown);
    socket.off(SocketEvents.raceStarted);
    socket.off(SocketEvents.raceParticipantStatus);
    socket.off(SocketEvents.raceFinished);
    socket.off(SocketEvents.racePlayerJoined);
    super.dispose();
  }

  void _setupSocketListeners() {
    final socket = ref.read(socketServiceProvider);

    socket.emit('join_room', { 'room': 'race:${widget.roomId}' });

    socket.on(SocketEvents.racePlayerJoined, (data) {
      if (mounted) _loadRoom();
    });

    socket.on(SocketEvents.raceCountdown, (data) {
      if (!mounted) return;
      final secs = (data['seconds'] as num?)?.toInt() ?? 5;
      setState(() => _countdown = secs);
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() => _countdown--);
        if (_countdown <= 0) t.cancel();
      });
    });

    socket.on(SocketEvents.raceStarted, (data) {
      if (!mounted) return;
      setState(() { _raceStarted = true; _countdown = 0; _elapsedSeconds = 0; });
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsedSeconds++);
      });
    });

    socket.on(SocketEvents.raceParticipantStatus, (data) {
      if (!mounted) return;
      _loadRoom();
    });

    socket.on(SocketEvents.raceFinished, (data) {
      if (!mounted) return;
      _elapsedTimer?.cancel();
      final results = (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      context.pushReplacement('/races/${widget.roomId}/results', extra: results);
    });
  }

  Future<void> _loadRoom() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/races/${widget.roomId}');
    if (mounted) setState(() => _room = res.data['data']);
  }

  Future<void> _startRace() async {
    final api = ref.read(apiClientProvider);
    await api.post('/races/${widget.roomId}/start');
  }

  Future<void> _updateStatus(String status) async {
    final api = ref.read(apiClientProvider);
    await api.patch('/races/${widget.roomId}/status', data: { 'status': status });
    setState(() => _myStatus = status);
  }

  /// The server only accepts a finish once LeetCode shows the accepted
  /// submission (409 until then), so only mark ACCEPTED on success.
  Future<void> _submitSolve() async {
    setState(() => _isSubmitting = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.post('/races/${widget.roomId}/solve');
      if (!mounted) return;
      setState(() { _isSubmitting = false; _myStatus = 'ACCEPTED'; });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      LCToastManager.show(
        context,
        title: e.response?.statusCode == 409 ? 'Not verified yet' : 'Could not submit',
        subtitle: e.response?.statusCode == 409
            ? 'LeetCode has not shown your accepted submission yet. Try again in a few seconds.'
            : 'Check your connection and try again',
        accentColor: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final participants = (room?['participants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final code = room?['code'] as String? ?? '------';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: LCAppBar(
        title: 'Race Room',
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.screenPadding),
              child: GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: code)),
                child: Row(
                  children: [
                    Text(code, style: AppTypography.stat(fontSize: 16, color: AppColors.primary)),
                    const SizedBox(width: 4),
                    const Icon(PhosphorIconsBold.copy, size: 12, color: AppColors.onSurfaceDim),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          children: [
            // ── Problem ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsBold.code, size: 14, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      room?['problemSlug'] ?? '—',
                      style: AppTypography.stat(fontSize: 14, color: AppColors.onSurface),
                    ),
                  ),
                  if (_raceStarted)
                    Text(
                      _formatElapsed(_elapsedSeconds),
                      style: AppTypography.stat(fontSize: 14, color: AppColors.primary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Countdown overlay ─────────────────────────────
            if (_countdown > 0)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  children: [
                    Text(
                      '$_countdown',
                      style: AppTypography.stat(fontSize: 72, color: AppColors.primary),
                    ),
                    Text('STARTING', style: AppTypography.tacticalLabel(color: AppColors.primary)),
                  ],
                ),
              ),

            // ── Participants ──────────────────────────────────
            Text('PARTICIPANTS', style: AppTypography.tacticalLabel()),
            const SizedBox(height: AppSpacing.md),
            ...participants.map((p) => _ParticipantRow(participant: p)),

            const Spacer(),

            // ── Actions ───────────────────────────────────────
            if (!_raceStarted && widget.isCreator)
              SizedBox(
                width: double.infinity,
                child: LCButton(
                  label: 'START RACE',
                  icon: PhosphorIconsBold.flagCheckered,
                  isExpanded: true,
                  onPressed: _startRace,
                ),
              ),

            if (_raceStarted && _myStatus != 'ACCEPTED') ...[
              _StatusSelector(
                current: _myStatus,
                onSelect: _updateStatus,
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: LCButton(
                  label: 'I GOT ACCEPTED — VERIFY',
                  icon: PhosphorIconsBold.checkCircle,
                  isLoading: _isSubmitting,
                  isExpanded: true,
                  onPressed: _submitSolve,
                ),
              ),
            ],

            if (_myStatus == 'ACCEPTED')
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsBold.checkCircle, color: AppColors.success, size: 18),
                    const SizedBox(width: AppSpacing.md),
                    Text('ACCEPTED — WAITING FOR OTHERS',
                        style: AppTypography.tacticalLabel(color: AppColors.success)),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant});
  final Map<String, dynamic> participant;

  Color get _statusColor {
    switch (participant['status'] as String?) {
      case 'ACCEPTED': return AppColors.success;
      case 'TESTING': return AppColors.warning;
      case 'CODING': return AppColors.primary;
      case 'THINKING': return AppColors.secondary;
      default: return AppColors.onSurfaceDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = participant['user'] as Map<String, dynamic>?;
    final status = participant['status'] as String? ?? 'WAITING';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor,
              boxShadow: [BoxShadow(color: _statusColor.withValues(alpha: 0.4), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              user?['displayName'] ?? '—',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            status,
            style: AppTypography.tacticalLabel(fontSize: 8, color: _statusColor),
          ),
          if (participant['rank'] != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              '#${participant['rank']}',
              style: AppTypography.stat(fontSize: 12, color: _statusColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.current, required this.onSelect});
  final String current;
  final void Function(String) onSelect;

  static const _statuses = ['THINKING', 'CODING', 'TESTING'];
  static const _colors = [AppColors.secondary, AppColors.primary, AppColors.warning];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_statuses.length, (i) {
        final isSelected = current == _statuses[i];
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(_statuses[i]),
            child: Container(
              margin: EdgeInsets.only(right: i < _statuses.length - 1 ? 4 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _colors[i].withValues(alpha: 0.15) : AppColors.surfaceVariant,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: isSelected ? _colors[i].withValues(alpha: 0.4) : AppColors.surfaceBorder,
                  width: isSelected ? 1 : 0.5,
                ),
              ),
              child: Text(
                _statuses[i],
                textAlign: TextAlign.center,
                style: AppTypography.tacticalLabel(
                  fontSize: 8,
                  color: isSelected ? _colors[i] : AppColors.onSurfaceDim,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
