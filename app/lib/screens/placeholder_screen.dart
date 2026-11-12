import 'package:flutter/material.dart';

/// Temporary screen for PRD pages not implemented yet (plants, process view, equipment, alarms,
/// trends, commands, setpoints, maintenance, simulation).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Not implemented yet.')),
      );
}
