import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/permissions.dart';
import '../app/providers.dart';
import '../components/plant_scaffold.dart';
import '../components/state_views.dart';

final handoversProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, plantId) async {
  ref.watch(sessionProvider);
  return ref
      .watch(supabaseProvider)
      .from('shift_handovers')
      .select('id, notes, created_at, author')
      .eq('plant_id', plantId)
      .order('created_at', ascending: false)
      .limit(50); // bounded result set
});

/// Shift handover notes. User text is rendered with Text/SelectableText only (never as HTML),
/// length-bounded, and written under RLS (author must be the caller and a plant member).
class ShiftHandoverScreen extends ConsumerStatefulWidget {
  const ShiftHandoverScreen({super.key, required this.plantId});
  final String plantId;
  @override
  ConsumerState<ShiftHandoverScreen> createState() => _ShiftHandoverScreenState();
}

class _ShiftHandoverScreenState extends ConsumerState<ShiftHandoverScreen> {
  static const maxLength = 2000;
  final _notes = TextEditingController();

  Future<void> _save() async {
    final text = _notes.text.trim();
    if (text.isEmpty || text.length > maxLength) return;
    try {
      await ref.read(supabaseProvider).from('shift_handovers').insert({'plant_id': widget.plantId, 'notes': text});
      _notes.clear();
      ref.invalidate(handoversProvider(widget.plantId));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The note could not be saved.')));
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(handoversProvider(widget.plantId));
    return PlantScaffold(
      plantId: widget.plantId,
      section: PlantSection.handover,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _notes,
              maxLength: maxLength,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Handover notes', border: OutlineInputBorder()),
            ),
          ),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save note')),
          const SizedBox(height: 8),
          Expanded(
            child: notes.when(
              loading: () => const LoadingView(label: 'Loading notes…'),
              error: (_, __) => ErrorView(message: 'Could not load notes.', onRetry: () => ref.invalidate(handoversProvider(widget.plantId))),
              data: (rows) => rows.isEmpty
                  ? const EmptyView(message: 'No handover notes yet.', icon: Icons.assignment_outlined)
                  : ListView(
                      children: [
                        for (final r in rows)
                          ListTile(
                            title: SelectableText(r['notes'] as String),
                            subtitle: Text(formatTime(DateTime.parse(r['created_at'] as String).toLocal())),
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
