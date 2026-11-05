import 'package:flutter/material.dart';

const ifsulGreen = Color(0xFF2F9E41);
const ifsulDarkGreen = Color(0xFF007A33);

/// Largura máxima do conteúdo em telas largas.
const contentMaxWidth = 720.0;

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: ifsulGreen).copyWith(
    primary: ifsulDarkGreen,
    onPrimary: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
  );
}

/// Centraliza o conteúdo numa coluna estreita em telas largas.
class CenteredColumn extends StatelessWidget {
  const CenteredColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: contentMaxWidth),
          child: child,
        ),
      );
}
