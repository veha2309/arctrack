import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../common.dart';
import '../theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _backupRefresh = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appControllerProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('History'), actions: [
          PopupMenuButton<String>(
              onSelected: (v) => _handleMenu(v),
              itemBuilder: (_) => const [
                    PopupMenuItem(value: 'csv', child: Text('Share CSV')),
                    PopupMenuItem(
                        value: 'json', child: Text('Share JSON backup')),
                    PopupMenuDivider(),
                    PopupMenuItem(
                        value: 'file', child: Text('Restore backup file')),
                    PopupMenuItem(
                        value: 'paste', child: Text('Paste JSON backup')),
                  ])
        ]),
        body: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (data) => CustomScrollView(slivers: [
                  SliverToBoxAdapter(
                      child: _BackupSection(
                          refreshKey: _backupRefresh,
                          onChoose: _chooseAutoBackup,
                          onUseExisting: _useExistingAutoBackup,
                          onDisable: _disableAutoBackup,
                          onRestoreFile: _restoreFile,
                          onPaste: _pasteBackup)),
                  if (data.sessions.isEmpty)
                    const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                            title: 'No workout history',
                            body:
                                'Completed sessions will be stored here offline.'))
                  else
                    SliverList.builder(
                        itemCount: data.sessions.length,
                        itemBuilder: (context, i) => _SessionTile(
                            data: data,
                            session: data.sessions[i],
                            onDelete: () => _deleteWorkout(data.sessions[i])))
                ])));
  }

  Future<void> _handleMenu(String kind) async {
    if (kind == 'file') return _restoreFile();
    if (kind == 'paste') return _pasteBackup();
    final controller = ref.read(appControllerProvider.notifier);
    final text =
        kind == 'csv' ? controller.exportCsv() : await controller.exportJson();
    await Share.share(text,
        subject:
            kind == 'csv' ? 'ArcTrack workout history' : 'ArcTrack backup');
  }

  Future<void> _chooseAutoBackup() async {
    try {
      final selected = await ref
          .read(appControllerProvider.notifier)
          .chooseAutoBackupDestination();
      if (!mounted || !selected) return;
      setState(() => _backupRefresh++);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Auto-backup enabled. ArcTrack will update this same file.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not create the selected backup file.')));
      }
    }
  }

  Future<void> _disableAutoBackup() async {
    await ref.read(appControllerProvider.notifier).disableAutoBackup();
    if (!mounted) return;
    setState(() => _backupRefresh++);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Automatic backup disabled')));
  }

  Future<void> _useExistingAutoBackup() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Use an existing backup?'),
            content: const Text(
                'Restore that file first if this is a new installation. ArcTrack will replace the selected file with the data currently in the app, then keep updating it.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Choose file')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      final selected = await ref
          .read(appControllerProvider.notifier)
          .useExistingAutoBackupDestination();
      if (!mounted || !selected) return;
      setState(() => _backupRefresh++);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Existing file linked for automatic backup')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not use the selected backup file.')));
      }
    }
  }

  Future<void> _restoreFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (!mounted || picked == null) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      _showRestoreError('Could not read the selected file.');
      return;
    }
    await _restoreRaw(utf8.decode(bytes));
  }

  Future<void> _pasteBackup() async {
    final input = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste JSON backup'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: input,
            autofocus: true,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: '{"exercises": [...]}',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, input.text),
              child: const Text('Continue')),
        ],
      ),
    );
    input.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    await _restoreRaw(raw);
  }

  Future<void> _restoreRaw(String raw) async {
    try {
      final restored = AppData.decode(raw);
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Restore this backup?'),
              content: Text(
                  '${restored.sessions.length} workouts, ${restored.templates.where((e) => !e.isRest).length} routines, and ${restored.measurements.length} measurements will replace the data currently on this device.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Restore')),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      await ref.read(appControllerProvider.notifier).importJson(raw);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Backup restored')));
      }
    } catch (_) {
      _showRestoreError('This is not a valid ArcTrack JSON backup.');
    }
  }

  void _showRestoreError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteWorkout(WorkoutSession session) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete ${session.name}?'),
            content: Text(
                'The workout from ${DateFormat('d MMM yyyy, H:mm').format(session.startedAt)} and all of its logged sets will be permanently removed.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete',
                      style: TextStyle(color: ArcColors.danger))),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      ref.read(appControllerProvider.notifier).deleteWorkout(session.id);
    }
  }
}

class _BackupSection extends ConsumerWidget {
  const _BackupSection({
    required this.refreshKey,
    required this.onChoose,
    required this.onUseExisting,
    required this.onDisable,
    required this.onRestoreFile,
    required this.onPaste,
  });
  final int refreshKey;
  final VoidCallback onChoose;
  final VoidCallback onUseExisting;
  final VoidCallback onDisable;
  final VoidCallback onRestoreFile;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ArcColors.line))),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: FutureBuilder<bool>(
          key: ValueKey(refreshKey),
          future: ref.read(appControllerProvider.notifier).isAutoBackupEnabled,
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? false;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('BACKUP & RESTORE',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ArcColors.muted))),
                  Text(enabled ? 'AUTO-BACKUP ON' : 'OFF',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: enabled ? ArcColors.accent : ArcColors.muted)),
                ]),
                const SizedBox(height: 8),
                Text(
                    enabled
                        ? 'Changes overwrite your selected backup file. If it is in Google Drive, Drive syncs it when internet is available.'
                        : 'Choose one local or Google Drive JSON file. ArcTrack will keep updating that same file.',
                    style: const TextStyle(color: ArcColors.muted)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.tonalIcon(
                      onPressed: onChoose,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: Text(enabled
                          ? 'Change backup file'
                          : 'Choose backup file')),
                  if (!enabled)
                    OutlinedButton(
                        onPressed: onUseExisting,
                        child: const Text('Use existing')),
                  OutlinedButton(
                      onPressed: onRestoreFile,
                      child: const Text('Restore file')),
                  OutlinedButton(
                      onPressed: onPaste, child: const Text('Paste JSON')),
                  if (enabled)
                    TextButton(
                        onPressed: onDisable, child: const Text('Disable')),
                ]),
              ],
            );
          },
        ),
      );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile(
      {required this.data, required this.session, required this.onDelete});
  final AppData data;
  final WorkoutSession session;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      childrenPadding: const EdgeInsets.only(bottom: 10),
      shape: const Border(bottom: BorderSide(color: ArcColors.line)),
      collapsedShape: const Border(bottom: BorderSide(color: ArcColors.line)),
      title: Text(session.name,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
          '${DateFormat('EEE, d MMM · H:mm').format(session.startedAt)} · ${session.workingSets} sets'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
            '${formatWeight(session.volume, data.useKg)} ${weightUnit(data.useKg)}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        PopupMenuButton<String>(
            tooltip: 'Workout actions',
            onSelected: (action) {
              if (action == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete workout')),
                ]),
      ]),
      children: session.exercises.map((log) {
        final exercise =
            data.exercises.where((e) => e.id == log.exerciseId).firstOrNull;
        final best = log.sets.where((s) => s.completed).fold<LoggedSet?>(null,
            (best, s) => best == null || s.volume > best.volume ? s : best);
        return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(exercise?.name ?? 'Exercise'),
            subtitle: Text(
                '${log.sets.where((s) => s.completed).length} completed sets'),
            trailing: best == null
                ? null
                : Text(
                    '${formatWeight(best.weightKg, data.useKg)} ${weightUnit(data.useKg)} × ${best.reps}'));
      }).toList());
}
