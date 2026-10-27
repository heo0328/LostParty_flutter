import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Localize only the picker; stored times and the surrounding app stay in KST.
Future<int?> showRecruitmentTimePicker(
  BuildContext context, {
  int? initial,
  TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
}) async {
  final result = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: (initial ?? 1200) ~/ 60,
      minute: (initial ?? 1200) % 60,
    ),
    initialEntryMode: initialEntryMode,
    helpText: '시간 선택',
    hourLabelText: '시간',
    minuteLabelText: '분',
    cancelText: '취소',
    confirmText: '선택',
    builder: (context, child) => Localizations.override(
      context: context,
      locale: const Locale('ko', 'KR'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: Theme.of(context).timePickerTheme.copyWith(
            // The SDK's 12-hour input mode needs 280px inside the dialog.
            padding: MediaQuery.sizeOf(context).width < 360
                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 16)
                : null,
          ),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 1,
            child: child!,
          ),
        ),
      ),
    ),
  );
  return result == null ? null : result.hour * 60 + result.minute;
}
