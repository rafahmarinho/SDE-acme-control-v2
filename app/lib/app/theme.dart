import 'package:flutter/material.dart';

/// Dark Material 3 theme (PRD: "Quero uma interface escura").
final acmeDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5), brightness: Brightness.dark),
);
