import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lc_app_bar.dart';
import '../../../../shared/widgets/lc_button.dart';

/// Create a new squad/group.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
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
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    // TODO: Call API to create group
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.pop(context);
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
            Text('SQUAD NAME', style: AppTypography.tacticalLabel()),
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

            Text('DESCRIPTION', style: AppTypography.tacticalLabel()),
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
              'AN INVITE CODE WILL BE GENERATED AUTOMATICALLY',
              style: AppTypography.tacticalLabel(
                fontSize: 8,
                color: AppColors.onSurfaceDim,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: LCButton(
                label: 'CREATE SQUAD',
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
