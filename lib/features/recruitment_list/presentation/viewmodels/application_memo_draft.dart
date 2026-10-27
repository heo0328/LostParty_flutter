import 'package:flutter/material.dart';
import '../../domain/application_memo_policy.dart';

class ApplicationMemoDraft extends ChangeNotifier {
  ApplicationMemoDraft() {
    input.addListener(notifyListeners);
  }
  final input = TextEditingController();
  bool get composing =>
      input.value.composing.isValid && !input.value.composing.isCollapsed;
  MemoValidation get validation => ApplicationMemoPolicy.check(input.text);
  bool get canSubmit => !composing && validation.valid;
  void select(String text) => input.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  @override
  void dispose() {
    input.removeListener(notifyListeners);
    input.dispose();
    super.dispose();
  }
}
