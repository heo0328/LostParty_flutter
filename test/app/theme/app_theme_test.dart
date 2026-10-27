import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/theme/app_colors.dart';
import 'package:lost_party/app/theme/app_radius.dart';
import 'package:lost_party/app/theme/app_theme.dart';

void main() {
  test('light theme exposes the LostParty surface and navigation tokens', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.navigationBarTheme.backgroundColor, AppColors.surface);
    expect(theme.navigationBarTheme.indicatorColor, AppColors.primarySubtle);

    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(AppRadius.large));
    expect(shape.side.color, AppColors.outline);
    expect(theme.cardTheme.elevation, 0);
  });

  test('selected navigation content uses the strong purple token', () {
    final theme = AppTheme.light.navigationBarTheme;
    final selected = <WidgetState>{WidgetState.selected};

    expect(theme.iconTheme!.resolve(selected)!.color, AppColors.primaryStrong);
    expect(
      theme.labelTextStyle!.resolve(selected)!.color,
      AppColors.primaryStrong,
    );
  });
  test(
    'disabled selection icons remain visible and enabled colors use SDK defaults',
    () {
      final theme = AppTheme.light;
      for (final selected in [false, true]) {
        final states = <WidgetState>{
          WidgetState.disabled,
          if (selected) WidgetState.selected,
        };
        expect(
          theme.checkboxTheme.fillColor!.resolve(states),
          AppColors.textSecondary,
        );
        expect(
          theme.radioTheme.fillColor!.resolve(states),
          AppColors.textSecondary,
        );
        expect(
          theme.switchTheme.thumbColor!.resolve(states),
          AppColors.textSecondary,
        );
      }
      expect(theme.checkboxTheme.fillColor!.resolve({}), isNull);
      expect(
        theme.radioTheme.fillColor!.resolve({WidgetState.selected}),
        isNull,
      );
      expect(
        theme.switchTheme.thumbColor!.resolve({WidgetState.selected}),
        isNull,
      );
    },
  );
}
