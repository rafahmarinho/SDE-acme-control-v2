import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'settings_screen.dart';

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  return ref.watch(supabaseProvider).from('profiles').select('id, display_name, phone').eq('id', session.user.id).maybeSingle();
});

/// Self-service profile: users view and correct their own data (single source of truth in
/// Supabase, shared by web and mobile). Role and email cannot be changed here.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loaded = false;

  Future<void> _save(bool phoneConsent) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final uid = ref.read(supabaseProvider).auth.currentUser?.id;
    if (uid == null) return;
    await ref.read(supabaseProvider).from('profiles').update({
      'display_name': _name.text.trim(),
      'phone': phoneConsent && _phone.text.trim().isNotEmpty ? _phone.text.trim() : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
    ref.invalidate(profileProvider);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final consents = ref.watch(currentConsentsProvider).valueOrNull ?? const {};
    final phoneConsent = consents['profile_optional_fields'] ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load your profile.')),
        data: (p) {
          if (p != null && !_loaded) {
            _name.text = p['display_name'] as String? ?? '';
            _phone.text = p['phone'] as String? ?? '';
            _loaded = true;
          }
          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name.' : null,
                ),
                TextFormField(
                  controller: _phone,
                  enabled: phoneConsent,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone (optional)',
                    helperText: phoneConsent ? 'International format, e.g. +5511999999999' : 'Enable optional profile details in Settings to add a phone number.',
                  ),
                  validator: (v) => (v == null || v.isEmpty || RegExp(r'^\+[0-9]{8,15}$').hasMatch(v)) ? null : 'Use international format.',
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => _save(phoneConsent), child: const Text('Save')),
              ],
            ),
          );
        },
      ),
    );
  }
}
