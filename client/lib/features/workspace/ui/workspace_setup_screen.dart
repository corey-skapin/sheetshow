import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/core/services/workspace_service.dart';
import 'package:sheetshow/core/theme/app_spacing.dart';

/// Shown on first launch (or when no workspace is configured).
///
/// The user picks a root folder. If `<folder>/.sheetshow/data.db` already
/// exists, all prior data is restored automatically.
class WorkspaceSetupScreen extends ConsumerStatefulWidget {
  const WorkspaceSetupScreen({super.key});

  @override
  ConsumerState<WorkspaceSetupScreen> createState() =>
      _WorkspaceSetupScreenState();
}

class _WorkspaceSetupScreenState extends ConsumerState<WorkspaceSetupScreen> {
  String? _selectedPath;
  bool _hasExistingData = false;
  bool _isSaving = false;

  Future<void> _pickFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    final dbFile = File(
      path.join(dirPath, '.sheetshow', 'data.db'),
    );
    final hasExisting = await dbFile.exists();

    if (mounted) {
      setState(() {
        _selectedPath = dirPath;
        _hasExistingData = hasExisting;
      });
    }
  }

  Future<void> _confirm() async {
    if (_selectedPath == null) return;
    setState(() => _isSaving = true);
    try {
      final workspaceService = ref.read(workspaceServiceProvider);
      await workspaceService.setWorkspacePath(_selectedPath!);
      await workspaceService.ensureSheetshowDir(_selectedPath!);
      // Invalidate the database provider so it re-opens at the new path.
      ref.invalidate(databaseProvider);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.folder_special,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Choose Your Workspace',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Pick the folder where your sheet music PDFs live. '
                  'SheetShow will keep a database inside that folder so '
                  'your library is portable.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse for folder…'),
                ),
                if (_selectedPath != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPath!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (_hasExistingData) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Existing library found — all data will be restored.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Fresh setup — PDFs will be imported from this folder.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed:
                      _selectedPath != null && !_isSaving ? _confirm : null,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Set as Workspace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
