import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../models/models.dart';
import 'account_menu.dart';
import 'state_views.dart';

/// Breakpoint between the phone layout (bottom tabs) and the tablet/web layout (side rail).
const wideLayoutBreakpoint = 900.0;

/// Responsive shell for every plant page.
/// - Wide (web / tablet): NavigationRail with every section the role can use.
/// - Narrow (phone): bottom tabs Plant / Alarms / Assets / More (PRD: "use abas para planta,
///   alarmes, ativos e outras opções"); "More" opens the remaining role-specific sections.
/// Navigation is adapted to the role for UX only; the API/RLS enforce permissions.
class PlantScaffold extends ConsumerWidget {
  const PlantScaffold({super.key, required this.plantId, required this.section, required this.body, this.actions = const [], this.floatingActionButton, this.title});

  final String plantId;
  final PlantSection section;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final String? title;

  static const _tabs = [PlantSection.process, PlantSection.alarms, PlantSection.equipment];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(plantRoleProvider(plantId)).valueOrNull;
    final sections = sectionsFor(role);
    final plantName = ref.watch(plantNameProvider(plantId));
    final alarmCount = ref.watch(activeAlarmCountProvider(plantId)).valueOrNull ?? 0;
    final online = isOnline(ref);
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;

    Widget sectionIcon(PlantSection s, {bool selected = false}) {
      final icon = Icon(selected ? _icons[s]!.$2 : _icons[s]!.$1);
      if (s == PlantSection.alarms && alarmCount > 0) return Badge(label: Text('$alarmCount'), child: icon);
      return icon;
    }

    final appBar = AppBar(
      leading: IconButton(tooltip: 'All plants', icon: const Icon(Icons.factory_outlined), onPressed: () => context.go('/plants')),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title ?? section.label),
        Text(
          role == null ? plantName : '$plantName · ${roleLabel(role)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ]),
      actions: [...actions, const AccountMenu()],
    );

    final content = Column(children: [
      if (!online) const OfflineBanner(),
      Expanded(child: body),
    ]);

    if (wide) {
      final selected = sections.indexOf(section);
      return Scaffold(
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: Row(children: [
          NavigationRail(
            labelType: NavigationRailLabelType.all,
            selectedIndex: selected < 0 ? null : selected,
            onDestinationSelected: (i) => context.go(sections[i].route(plantId)),
            destinations: [
              for (final s in sections)
                NavigationRailDestination(icon: sectionIcon(s), selectedIcon: sectionIcon(s, selected: true), label: Text(s.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ]),
      );
    }

    final tabIndex = _tabs.contains(section) ? _tabs.indexOf(section) : 3;
    final more = sections.where((s) => !_tabs.contains(s)).toList();
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) {
          if (i < _tabs.length) {
            context.go(_tabs[i].route(plantId));
          } else {
            _openMore(context, more);
          }
        },
        destinations: [
          NavigationDestination(icon: sectionIcon(PlantSection.process), selectedIcon: sectionIcon(PlantSection.process, selected: true), label: 'Plant'),
          NavigationDestination(icon: sectionIcon(PlantSection.alarms), selectedIcon: sectionIcon(PlantSection.alarms, selected: true), label: 'Alarms'),
          NavigationDestination(icon: sectionIcon(PlantSection.equipment), selectedIcon: sectionIcon(PlantSection.equipment, selected: true), label: 'Assets'),
          const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  void _openMore(BuildContext context, List<PlantSection> more) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final s in more)
            ListTile(
              leading: Icon(_icons[s]!.$1),
              title: Text(s.label),
              selected: s == section,
              minTileHeight: 56, // touch-friendly targets
              onTap: () {
                Navigator.of(ctx).pop();
                context.go(s.route(plantId));
              },
            ),
          const Divider(),
          ListTile(leading: const Icon(Icons.person_outline), title: const Text('Profile'), onTap: () {
            Navigator.of(ctx).pop();
            context.push('/profile');
          }),
          ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Settings'), onTap: () {
            Navigator.of(ctx).pop();
            context.push('/settings');
          }),
        ]),
      ),
    );
  }
}

const _icons = <PlantSection, (IconData, IconData)>{
  PlantSection.process: (Icons.water_outlined, Icons.water),
  PlantSection.alarms: (Icons.notifications_outlined, Icons.notifications_active),
  PlantSection.equipment: (Icons.precision_manufacturing_outlined, Icons.precision_manufacturing),
  PlantSection.trends: (Icons.show_chart, Icons.show_chart),
  PlantSection.commands: (Icons.toggle_off_outlined, Icons.toggle_on),
  PlantSection.setpoints: (Icons.tune, Icons.tune),
  PlantSection.maintenance: (Icons.build_outlined, Icons.build),
  PlantSection.handover: (Icons.assignment_outlined, Icons.assignment),
};
