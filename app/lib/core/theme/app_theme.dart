import 'package:flutter/material.dart';

/// Geçici tema. Nihai görsel tasarım en sona bırakıldı (bkz. project.md §3.0).
/// Şimdilik Material 3 + tek bir tohum renkten üretilen açık/koyu tema.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF4F6CFF);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
