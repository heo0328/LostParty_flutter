import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/theme/app_theme.dart';
import 'package:lost_party/app/theme/app_colors.dart';

void main() {
  test('disabled radios preserve selected and unselected colors', () {
    final theme = AppTheme.light;
    final colors = theme.radioTheme.fillColor!;
    for (final selected in [false, true]) {
      final enabled = <WidgetState>{if (selected) WidgetState.selected};
      expect(
        colors.resolve({...enabled, WidgetState.disabled}),
        colors.resolve(enabled),
      );
    }
    expect(
      colors.resolve({WidgetState.selected, WidgetState.disabled}),
      AppColors.primary,
    );
    expect(colors.resolve({WidgetState.disabled}), isNot(AppColors.primary));
    for (final property in [
      theme.switchTheme.thumbColor!,
      theme.switchTheme.trackColor!,
      theme.switchTheme.trackOutlineColor!,
      theme.checkboxTheme.fillColor!,
      theme.checkboxTheme.checkColor!,
    ]) {
      for (final selected in [false, true]) {
        final states = <WidgetState>{if (selected) WidgetState.selected};
        expect(
          property.resolve({...states, WidgetState.disabled}),
          property.resolve(states),
        );
      }
    }
  });
}
