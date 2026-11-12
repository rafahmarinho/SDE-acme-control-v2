import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Shift handover')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(controller: _notes, maxLength: maxLength, maxLines: 4, decoration: const InputDecoration(labelText: 'Handover notes')),
          ),
          FilledButton(onPressed: _save, child: const Text('Save note')),
          Expanded(
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Could not load notes.')),
              data: (rows) => rows.isEmpty
                  ? const Center(child: Text('No handover notes yet.'))
                  : ListView(
                      children: [
                        for (final r in rows)
                          ListTile(
                            title: SelectableText(r['notes'] as String),
                            subtitle: Text(DateTime.parse(r['created_at'] as String).toLocal().toString()),
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
