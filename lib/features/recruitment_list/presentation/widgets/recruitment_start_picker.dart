import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class RecruitmentStartPicker extends StatefulWidget {
  const RecruitmentStartPicker({
    required this.allowed,
    required this.resetLabel,
    this.initial,
    super.key,
  });
  final bool Function(int minute) allowed;
  final int? initial;
  final String? resetLabel;

  @override
  State<RecruitmentStartPicker> createState() => _RecruitmentStartPickerState();
}

class _RecruitmentStartPickerState extends State<RecruitmentStartPicker> {
  late int _selected;
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    final preferred = widget.initial ?? 1200;
    _selected = widget.allowed(preferred)
        ? preferred
        : List.generate(288, (i) => i * 5).where(widget.allowed).firstOrNull ??
              preferred;
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Widget _choices({required bool hours}) => GridView.count(
    crossAxisCount: 6,
    childAspectRatio: 1.25,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 3,
    crossAxisSpacing: 3,
    children: [
      for (var i = 0; i < (hours ? 24 : 12); i++)
        Builder(
          builder: (context) {
            final values = hours
                ? List.generate(
                    12,
                    (m) => i * 60 + m * 5,
                  ).where(widget.allowed).toList()
                : [
                    (_selected ~/ 60) * 60 + i * 5,
                  ].where(widget.allowed).toList();
            final enabled = values.isNotEmpty;
            final selected = hours
                ? _selected ~/ 60 == i
                : _selected % 60 == i * 5;
            return Opacity(
              opacity: enabled ? 1 : .35,
              child: ChoiceChip(
                label: Text(
                  '${(hours ? i : i * 5).toString().padLeft(2, '0')}${hours ? '시' : '분'}',
                  style: const TextStyle(fontSize: 12),
                ),
                labelPadding: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                showCheckmark: false,
                selected: selected && enabled,
                selectedColor: AppColors.primary.withValues(alpha: .15),
                onSelected: !enabled
                    ? null
                    : (_) => setState(() {
                        final candidate = hours
                            ? i * 60 + _selected % 60
                            : values.single;
                        _selected = widget.allowed(candidate)
                            ? candidate
                            : values.first;
                      }),
              ),
            );
          },
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('출발 시각 · KST'),
    content: SizedBox(
      width: 280,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('회색 시간은 선택할 수 없어요.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            _choices(hours: true),
            const SizedBox(height: 12),
            _choices(hours: false),
            if (!widget.allowed(_selected))
              const Text(
                '선택한 날짜에는 가능한 출발 시각이 없거나 선택 시각이 지났어요.',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      if (widget.resetLabel != null)
        TextButton(
          onPressed: () => Navigator.pop(context, -1),
          child: Text(widget.resetLabel!),
        ),
      FilledButton(
        onPressed: !widget.allowed(_selected)
            ? null
            : () {
                if (widget.allowed(_selected)) {
                  Navigator.pop(context, _selected);
                }
              },
        child: const Text('적용'),
      ),
    ],
  );
}
