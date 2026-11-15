import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../config.dart';

/// App-bar account menu: profile, settings, demo area (only when demo tools are compiled in) and
/// sign out. The simulation entry is hidden in production builds (T49).
class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (v) {
        switch (v) {
          case 'profile':
            context.push('/profile');
          case 'settings':
            context.push('/settings');
          case 'simulation':
            context.push('/simulation');
          case 'logout':
            ref.read(authServiceProvider).signOut();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'profile', child: ListTile(leading: Icon(Icons.person_outline), title: Text('Profile'))),
        const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings'))),
        if (AppConfig.enableDemoTools)
          const PopupMenuItem(value: 'simulation', child: ListTile(leading: Icon(Icons.science_outlined), title: Text('Simulation'))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out'))),
      ],
    );
  }
}
