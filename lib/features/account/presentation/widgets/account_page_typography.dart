import 'package:flutter/material.dart';

/// Account-only typography. Spacing, system text scaling and global theme stay intact.
class AccountPageTypography extends StatelessWidget {
  const AccountPageTypography({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final text = base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 14),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 16),
      labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 14),
      labelSmall: base.textTheme.labelSmall?.copyWith(fontSize: 14),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 18),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontSize: 16),
    );
    return Theme(
      data: base.copyWith(
        textTheme: text,
        filledButtonTheme: FilledButtonThemeData(
          style: base.filledButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(text.labelLarge),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: base.outlinedButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(text.labelLarge),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: base.textButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(text.labelLarge),
          ),
        ),
      ),
      child: child,
    );
  }
}
