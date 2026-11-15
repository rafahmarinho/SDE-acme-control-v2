import 'package:flutter/material.dart';

/// Fallback screen for invalid routes (e.g. a malformed plant id).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Not implemented yet.')),
      );
}
