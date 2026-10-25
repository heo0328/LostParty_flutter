import 'package:filter_profanity/filter_profanity.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

class MemoValidation {
  const MemoValidation(this.text, this.error);
  final String text;
  final String? error;
  bool get valid => error == null;
}

/// Input policy only. The text is never censored or silently stripped.
class ApplicationMemoPolicy {
  static final _allowed = RegExp(r'^[가-힣ㄱ-ㅣA-Za-z0-9 .,!\?~()_/@#&+\-]*$');
  static final _words = List<String>.unmodifiable({
    ...koreanOffensiveWords,
    ...englishOffensiveWords,
    '시발',
    '시팔',
    'ㅅㅂ',
    'ㅂㅅ',
  });
  // Attached Korean insults and separator evasion need more than token matching.
  // Ambiguous words (e.g. 보지/자지/망가) remain token-only, not substrings.
  static const _attached = [
    '개새끼',
    '개자식',
    '병신',
    '씨발',
    '씨팔',
    '시발',
    '시팔',
    '씹새',
    '씹팔',
    '좆',
    '섹스',
    '강간',
    '포르노',
    'ㅅㅂ',
    'ㅂㅅ',
  ];
  static MemoValidation check(String raw, {bool required = false}) {
    if (raw.length > 4096) {
      return MemoValidation(raw, '20자 이내로 입력해 주세요.');
    }
    final nfc = unicode.nfc(raw);
    final text = nfc.replaceAll(RegExp(r'^ +| +$'), '');
    if (!_allowed.hasMatch(nfc)) {
      return MemoValidation(text, '한글·영문·숫자와 허용된 기호만 입력해 주세요.');
    }
    if (text.length > 20) return MemoValidation(text, '20자 이내로 입력해 주세요.');
    if (required && text.isEmpty) {
      return MemoValidation(text, '저장할 문구를 입력해 주세요.');
    }
    final lower = text.toLowerCase();
    // These are common verb constructions in a raid memo, not sexual nouns.
    // Remove only the ambiguous verb from detection; still inspect the rest.
    final detection = lower.replaceAll(RegExp(r'(보지|자지)(?= *(못|않|말|마))'), '');
    final tokens = detection.replaceAll(RegExp(r'[^가-힣ㄱ-ㅣa-z0-9]+'), ' ');
    String? blocked;
    if (hasProfanity(tokens, offensiveWords: _words)) {
      final present = tokens.split(' ').toSet();
      blocked = _words.firstWhere(present.contains);
    }
    final compact = lower
        .replaceAll('시발점', '')
        .replaceAll('시발역', '')
        .replaceAll(RegExp(r'[^가-힣ㄱ-ㅣa-z0-9]'), '');
    blocked ??= _attached.where(compact.contains).firstOrNull;
    if (const ['fuck', 'shit', 'sex', 'porn'].contains(compact)) {
      blocked ??= compact;
    }
    return MemoValidation(
      text,
      blocked == null ? null : '$blocked은 금칙어로 설정되어 있습니다.',
    );
  }
}
