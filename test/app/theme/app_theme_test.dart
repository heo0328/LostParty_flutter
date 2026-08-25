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
}
