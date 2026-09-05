import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/app_controller.dart';
import '../../data/bulk_excel.dart';
import '../../domain/models.dart';
import '../common.dart';
import '../theme.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});
  static const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan'), actions: [
        PopupMenuButton<String>(
          onSelected: (value) => _menuAction(context, ref, value),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'exercise', child: Text('New exercise')),
            PopupMenuItem(value: 'import', child: Text('Import Excel')),
            PopupMenuItem(
                value: 'template', child: Text('Share Excel template')),
          ],
        )
      ]),
      floatingActionButton: async.value == null
          ? null
          : FloatingActionButton.small(
              onPressed: () => _newRoutine(context, ref, async.value!),
              child: const Icon(Icons.add)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => ListView(children: [
          SectionHeader('Routines',
              trailing: TextButton.icon(
                  onPressed: () => _newRoutine(context, ref, data),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New'))),
          ...data.templates.where((template) => !template.isRest).map(
                (template) => Column(children: [
                  ListTile(
                    title: Text(template.name),
                    subtitle: Text('${template.exercises.length} exercises'),
                    onTap: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .startTemplate(template);
                      context.go('/workout');
                    },
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Routine actions',
                      onSelected: (action) {
                        if (action == 'delete') {
                          _deleteRoutine(context, ref, template);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete routine')),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 16),
                ]),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: SegmentedButton<ScheduleMode>(
              segments: const [
                ButtonSegment(
                    value: ScheduleMode.rolling, label: Text('Rolling')),
                ButtonSegment(
                    value: ScheduleMode.weekly, label: Text('7-day week')),
              ],
              selected: {data.scheduleMode},
              onSelectionChanged: (value) => ref
                  .read(appControllerProvider.notifier)
                  .setScheduleMode(value.first),
              showSelectedIcon: false,
            ),
          ),
          if (data.scheduleMode == ScheduleMode.rolling)
            _RollingEditor(data: data)
          else
            _WeeklyEditor(data: data),
          const SectionHeader('Exercise library'),
          ...data.exercises.map((e) => Column(children: [
                ListTile(
                    dense: true,
                    title: Text(e.name),
                    subtitle: Text(e.muscle),
                    trailing: Text(e.kind.name.toUpperCase(),
                        style: const TextStyle(
                            color: ArcColors.muted, fontSize: 10))),
                const Divider(height: 1, indent: 16),
              ])),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Future<void> _menuAction(
      BuildContext context, WidgetRef ref, String value) async {
    if (value == 'exercise') return _newExercise(context, ref);
    final service = BulkExcelService();
    if (value == 'template') {
      final bytes = service.createTemplate();
      await Share.shareXFiles([
        XFile.fromData(bytes,
            name: 'arctrack_bulk_template.xlsx',
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      ], subject: 'ArcTrack bulk import template');
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (picked == null || !context.mounted) return;
    try {
      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        throw const FormatException('Could not read the selected file.');
      }
      final result =
          service.import(bytes, ref.read(appControllerProvider).requireValue);
      if (!context.mounted) return;
      final accepted = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                    title: const Text('Import workbook?'),
                    content: Text(
                        '${result.summary}.\n\nMatching workout names will be updated. Existing history is kept.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Import')),
                    ],
                  )) ??
          false;
      if (accepted) {
        ref.read(appControllerProvider.notifier).applyBulkImport(result.data);
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported ${result.summary}')));
      }
    } on FormatException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This workbook could not be imported. Check the template format.')));
    }
  }

  Future<void> _deleteRoutine(
      BuildContext context, WidgetRef ref, WorkoutTemplate template) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete ${template.name}?'),
            content: const Text(
                'The routine will be removed from rolling and weekly schedules. Completed workout history will be kept.'),
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
      ref.read(appControllerProvider.notifier).deleteTemplate(template.id);
    }
  }
}

class _RollingEditor extends ConsumerWidget {
  const _RollingEditor({required this.data});
  final AppData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        SectionHeader('Repeating split',
            trailing: TextButton.icon(
                onPressed: () => ref
                    .read(appControllerProvider.notifier)
                    .addRestToRotation(),
                icon: const Icon(Icons.bedtime_outlined, size: 16),
                label: const Text('Add rest'))),
        const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Runs continuously. Rest can appear as often as needed; missed days keep the current item.',
                    style: TextStyle(color: ArcColors.muted)))),
        if (data.rotation.isEmpty)
          const EmptyState(
              title: 'Empty split',
              body: 'Add a routine or rest day to build the sequence.'),
        ...data.rotation.asMap().entries.map((entry) {
          final template =
              data.templates.where((e) => e.id == entry.value).firstOrNull;
          if (template == null) return const SizedBox.shrink();
          return Column(children: [
            ListTile(
              leading: SizedBox(
                  width: 24,
                  child: Text('${entry.key + 1}',
                      style: TextStyle(
                          color: entry.key == data.rotationIndex
                              ? ArcColors.accent
                              : ArcColors.muted))),
              title: Text(template.name),
              subtitle: Text(template.isRest
                  ? 'Rest day'
                  : '${template.exercises.length} exercises'),
              onTap: template.isRest
                  ? null
                  : () {
                      ref
                          .read(appControllerProvider.notifier)
                          .startTemplate(template);
                      context.go('/workout');
                    },
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    tooltip: 'Move up',
                    onPressed: entry.key == 0
                        ? null
                        : () => ref
                            .read(appControllerProvider.notifier)
                            .moveRotationItem(entry.key, -1)),
                IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: 'Move down',
                    onPressed: entry.key == data.rotation.length - 1
                        ? null
                        : () => ref
                            .read(appControllerProvider.notifier)
                            .moveRotationItem(entry.key, 1)),
                IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove',
                    onPressed: () => ref
                        .read(appControllerProvider.notifier)
                        .removeRotationItem(entry.key)),
              ]),
            ),
            const Divider(height: 1, indent: 16),
          ]);
        }),
      ]);
}

class _WeeklyEditor extends ConsumerWidget {
  const _WeeklyEditor({required this.data});
  final AppData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        const SectionHeader('Fixed weekly split'),
        const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Each weekday repeats every week. Assign Rest to keep a fixed recovery day.',
                    style: TextStyle(color: ArcColors.muted)))),
        ...PlanScreen.days.asMap().entries.map((entry) {
          final value = data.weeklySchedule.length > entry.key
              ? data.weeklySchedule[entry.key]
              : null;
          return Column(children: [
            ListTile(
              title: Text(entry.value),
              trailing: SizedBox(
                  width: 190,
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                    value:
                        data.templates.any((e) => e.id == value) ? value : null,
                    isExpanded: true,
                    hint: const Text('Unscheduled'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Unscheduled')),
                      ...data.templates.map((e) => DropdownMenuItem<String?>(
                          value: e.id, child: Text(e.name))),
                    ],
                    onChanged: (id) => ref
                        .read(appControllerProvider.notifier)
                        .setWeeklyDay(entry.key, id),
                  ))),
            ),
            const Divider(height: 1, indent: 16),
          ]);
        }),
      ]);
}

Future<void> _newExercise(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final muscle = TextEditingController();
  var kind = ExerciseKind.strength;
  await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                title: const Text('New exercise'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: muscle,
                      decoration:
                          const InputDecoration(labelText: 'Primary muscle')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                      initialValue: kind,
                      decoration:
                          const InputDecoration(labelText: 'Tracking type'),
                      items: ExerciseKind.values
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)))
                          .toList(),
                      onChanged: (v) => setState(() => kind = v!)),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (name.text.trim().isEmpty ||
                            muscle.text.trim().isEmpty) return;
                        ref.read(appControllerProvider.notifier).addExercise(
                            name.text.trim(), muscle.text.trim(), kind);
                        Navigator.pop(context);
                      },
                      child: const Text('Add')),
                ],
              )));
}

Future<void> _newRoutine(
    BuildContext context, WidgetRef ref, AppData data) async {
  final name = TextEditingController();
  final selected = <String>{};
  await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                title: const Text('New routine'),
                content: SizedBox(
                    width: 420,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration:
                              const InputDecoration(labelText: 'Routine name')),
                      const SizedBox(height: 8),
                      Flexible(
                          child: ListView(
                              shrinkWrap: true,
                              children: data.exercises
                                  .map((e) => CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: selected.contains(e.id),
                                      title: Text(e.name),
                                      subtitle: Text(e.muscle),
                                      onChanged: (v) => setState(() => v!
                                          ? selected.add(e.id)
                                          : selected.remove(e.id))))
                                  .toList())),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (name.text.trim().isEmpty || selected.isEmpty)
                          return;
                        ref.read(appControllerProvider.notifier).addTemplate(
                            name.text.trim(),
                            selected
                                .map((id) => TemplateExercise(exerciseId: id))
                                .toList());
                        Navigator.pop(context);
                      },
                      child: const Text('Create')),
                ],
              )));
}
