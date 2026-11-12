import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Purposes that need explicit consent (see supabase consents table). Work-required processing
/// (audit of control actions) is described in the privacy notice instead.
const consentPurposes = {
  'profile_optional_fields': 'Store optional profile details (phone number)',
  'sms_alarm_notifications': 'Receive alarm notifications by SMS',
};
const privacyNoticeVersion = '2026-11';

final currentConsentsProvider = FutureProvider.autoDispose<Map<String, bool>>((ref) async {
  ref.watch(sessionProvider);
  final rows = await ref.watch(supabaseProvider).from('current_consents').select('purpose, granted');
  return {for (final r in rows) r['purpose'] as String: r['granted'] as bool};
});

/// Settings: consent management (grant/withdraw with one tap), clear offline data, sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setConsent(WidgetRef ref, String purpose, bool granted) async {
    // Append-only history: every decision is a new row with the notice version and timestamp.
    await ref.read(supabaseProvider).from('consents').insert({'purpose': purpose, 'granted': granted, 'notice_version': privacyNoticeVersion});
    if (!granted && purpose == 'profile_optional_fields') {
      final uid = ref.read(supabaseProvider).auth.currentUser?.id;
      if (uid != null) await ref.read(supabaseProvider).from('profiles').update({'phone': null}).eq('id', uid);
    }
    ref.invalidate(currentConsentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consents = ref.watch(currentConsentsProvider);
    void show(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(title: Text('Privacy')),
          consents.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const ListTile(title: Text('Could not load your privacy choices.')),
            data: (current) => Column(
              children: [
                for (final entry in consentPurposes.entries)
                  SwitchListTile(
                    title: Text(entry.value),
                    value: current[entry.key] ?? false,
                    onChanged: (v) => _setConsent(ref, entry.key, v),
                  ),
              ],
            ),
          ),
          const Divider(),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Clear offline data'),
              subtitle: const Text('Removes cached plant data from this device'),
              onTap: () async {
                await ref.read(offlineCacheProvider).wipe();
                show('Offline data cleared.');
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out of this device'),
            onTap: () => ref.read(authServiceProvider).signOut(),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Sign out of all devices'),
            onTap: () => ref.read(authServiceProvider).signOut(global: true),
          ),
        ],
      ),
    );
  }
}
