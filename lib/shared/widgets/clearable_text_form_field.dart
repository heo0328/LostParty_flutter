import 'package:flutter/material.dart';

class ClearableTextFormField extends StatelessWidget {
  const ClearableTextFormField({
    required this.controller,
    this.fieldKey,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.border,
    this.enabled,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.trailing,
    super.key,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final InputBorder? border;
  final bool? enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) => TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        border: border,
        suffixIcon: value.text.isEmpty && trailing == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.text.isNotEmpty)
                    IconButton(
                      key: ValueKey('clear-${fieldKey.toString()}'),
                      tooltip: '입력 지우기',
                      onPressed: enabled == false
                          ? null
                          : () {
                              controller.clear();
                              onChanged?.call('');
                            },
                      icon: const Icon(Icons.close),
                    ),
                  ?trailing,
                ],
              ),
      ),
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
    ),
  );
}
