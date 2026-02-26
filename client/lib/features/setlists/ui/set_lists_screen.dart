import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:sheetshow/features/setlists/models/set_list_model.dart';
import 'package:sheetshow/features/setlists/repositories/set_list_repository.dart';

// T060: SetListsScreen — list of all set lists with create/rename/delete.

class SetListsScreen extends ConsumerWidget {
  const SetListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Lists'),
        leading: BackButton(onPressed: () => context.go('/library')),
      ),
      body: StreamBuilder<List<SetListModel>>(
        stream: ref.watch(setListRepositoryProvider).watchAll(),
        builder: (context, snapshot) {
          final lists = snapshot.data ?? [];
          if (lists.isEmpty) {
            return const Center(
              child: Text('No set lists yet. Tap + to create one.'),
            );
          }
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (_, i) {
              final sl = lists[i];
              return ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(sl.name),
                subtitle: Text('${sl.entries.length} scores'),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Set list options',
                  onSelected: (v) {
                    if (v == 'rename') _rename(context, ref, sl);
                    if (v == 'delete') _delete(context, ref, sl);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => context.go('/setlists/${sl.id}/builder'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create set list',
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Set List'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Set list name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final now = DateTime.now();
    await ref.read(setListRepositoryProvider).create(
          SetListModel(
            id: const Uuid().v4(),
            name: name,
            entries: const [],
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, SetListModel sl) async {
    final controller = TextEditingController(text: sl.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Set List'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(setListRepositoryProvider).rename(sl.id, name);
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, SetListModel sl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Set List'),
        content: Text('Delete "${sl.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(setListRepositoryProvider).delete(sl.id);
    }
  }
}
