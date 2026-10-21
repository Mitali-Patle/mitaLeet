import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_button.dart';
import '../../../../shared/widgets/lc_toast.dart';
import '../../providers/groups_provider.dart';

/// Create a new squad/group.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      LCToastManager.show(context,
          title: 'Name too short', subtitle: 'Use at least 2 characters', accentColor: AppColors.error);
      return;
    }
    setState(() => _isLoading = true);
    final ok = await ref
        .read(groupsProvider.notifier)
        .createGroup(name, description: _descController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      LCToastManager.show(context,
          title: 'Squad created', subtitle: 'Share the invite code from the squad page', accentColor: AppColors.success);
      Navigator.pop(context);
    } else {
      LCToastManager.show(context,
          title: 'Could not create squad',
          subtitle: ref.read(groupsProvider).error ?? 'Please try again',
          accentColor: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const LCAppBar(title: 'Create Squad'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Squad name', style: AppTypography.tacticalLabel()),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'e.g. DSA Grinders',
                prefixIcon: Icon(PhosphorIconsBold.usersThree, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            Text('Description', style: AppTypography.tacticalLabel()),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descController,
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Optional description',
                prefixIcon: Icon(PhosphorIconsBold.textAlignLeft, size: 18),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'An invite code will be generated automatically',
              style: AppTypography.tacticalLabel(
                fontSize: 8,
                color: AppColors.onSurfaceDim,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: LCButton(
                label: 'Create squad',
                icon: PhosphorIconsBold.plus,
                isLoading: _isLoading,
                isExpanded: true,
                onPressed: _create,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
