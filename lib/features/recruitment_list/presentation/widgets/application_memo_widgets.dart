import 'dart:convert';
import 'recruitment_design.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../account/data/local/scoped_command_key.dart';
import '../../data/beta/recruitment_command.dart';
import '../../domain/application_memo_policy.dart';
import '../viewmodels/application_memo_draft.dart';
import '../viewmodels/application_messages_controller.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';

class ApplicationMemoComposer extends StatelessWidget {
  const ApplicationMemoComposer({
    super.key,
    required this.draft,
    required this.messages,
    required this.enabled,
  });
  final ApplicationMemoDraft draft;
  final ApplicationMessagesController? messages;
  final bool enabled;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: draft,
    builder: (context, _) {
      final m = messages;
      Widget content() => RecruitmentDesignCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '공대장에게 한마디',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${draft.validation.text.length}/20',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: draft.input,
              enabled: enabled,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.text,
              style: const TextStyle(fontSize: 14),
              decoration: recruitmentPaleInput(
                hint: '예: 시간 맞춰 참가할게요',
                error: draft.composing ? null : draft.validation.error,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '저장한 문구',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 116,
                  child: RecruitmentPrimaryButton(
                    label: '문구 관리',
                    secondary: true,
                    onPressed:
                        enabled &&
                            m?.document != null &&
                            !m!.loading &&
                            !m.saving
                        ? () {
                            final binding = m.scopeKey();
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _PresetsEditor(
                                  controller: m,
                                  initialBinding: binding,
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (m?.loading == true) const LinearProgressIndicator(minHeight: 2),
            if (m?.failure != null)
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '저장 문구를 확인하지 못했습니다.',
                      style: TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                  ),
                  TextButton(
                    onPressed: !m!.loading && !m.saving ? m.load : null,
                    child: const Text('다시 확인'),
                  ),
                ],
              ),
            if (m?.pending != null)
              const Text(
                '문구 관리에서 저장 결과를 확인해 주세요.',
                style: TextStyle(fontSize: 11),
              ),
            for (final item in m?.items ?? <Map<String, dynamic>>[])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: draft.validation.text == item['text']
                      ? recruitmentSelectionFill
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: enabled
                        ? () => draft.select(item['text'] as String)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Text(
                        item['text'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: draft.validation.text == item['text']
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: draft.validation.text == item['text']
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              '메모 없이도 신청할 수 있어요.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
      return m == null
          ? content()
          : ListenableBuilder(listenable: m, builder: (_, _) => content());
    },
  );
}

class _PresetsEditor extends StatefulWidget {
  const _PresetsEditor({
    required this.controller,
    required this.initialBinding,
  });
  final String initialBinding;
  final ApplicationMessagesController controller;
  @override
  State<_PresetsEditor> createState() => _PresetsEditorState();
}

class _PresetsEditorState extends State<_PresetsEditor> {
  ApplicationMessagesController get m => widget.controller;
  final rows = <({String id, TextEditingController input})>[];
  late final String binding;
  late int version;
  bool reviewed = false, needsReview = false;
  TextEditingController makeInput(String text) =>
      TextEditingController(text: text)..addListener(() {
        if (mounted) setState(() {});
      });
  @override
  void initState() {
    super.initState();
    binding = widget.initialBinding;
    version = m.document?.wire['version'] as int? ?? 1;
    final pending = m.pending;
    final original = pending == null
        ? null
        : jsonDecode(pending.rawBody) as Map;
    if (original != null) version = original['expected_version'] as int;
    for (final row in (original?['items'] as List? ?? m.items)) {
      rows.add((
        id: row['id'] as String,
        input: makeInput(row['text'] as String),
      ));
    }
  }

  @override
  void dispose() {
    for (final row in rows) {
      row.input.dispose();
    }
    super.dispose();
  }

  Future<void> save({bool retry = false}) async {
    if (m.scopeKey() != binding || !m.session.isAuthenticated) return;
    final result = retry
        ? await m.retry()
        : await m.save([
            for (final row in rows) {'id': row.id, 'text': row.input.text},
          ], version);
    if (mounted && m.failure == 'REVISION_CONFLICT') {
      setState(() => needsReview = true);
    }
    if (mounted && result && m.scopeKey() == binding) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: m,
    builder: (context, _) {
      final active = m.scopeKey() == binding && m.session.isAuthenticated;
      final editable = active && !m.loading && !m.saving && m.pending == null;
      final valid = rows.every(
        (r) =>
            r.input.value.composing.isCollapsed &&
            ApplicationMemoPolicy.check(r.input.text, required: true).valid,
      );
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('저장 문구 관리')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!active)
                const Text('계정이 변경되었습니다. 창을 닫고 다시 열어 주세요.')
              else ...[
                const Text(
                  '최대 5개 · 문구마다 20자',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '이 계정으로 다른 기기에서도 사용해요.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 32),
                for (final row in rows)
                  RecruitmentDesignCard(
                    padding: 12,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '저장 문구 ${rows.indexOf(row) + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: editable
                                  ? () => setState(() {
                                      rows.remove(row);
                                      row.input.dispose();
                                    })
                                  : null,
                              child: const Text(
                                '삭제',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextField(
                          key: ValueKey(row.id),
                          controller: row.input,
                          enabled: editable,
                          maxLines: 2,
                          minLines: 1,
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(fontSize: 14),
                          decoration: recruitmentPaleInput(
                            hint: '저장할 문구를 입력해 주세요.',
                            error:
                                row.input.value.composing.isValid &&
                                    !row.input.value.composing.isCollapsed
                                ? null
                                : ApplicationMemoPolicy.check(
                                    row.input.text,
                                    required: true,
                                  ).error,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (rows.length < 5)
                  RecruitmentPrimaryButton(
                    label: '문구 추가',
                    secondary: true,
                    onPressed: editable
                        ? () => setState(
                            () => rows.add((
                              id: newScopedCommandKey(),
                              input: makeInput(''),
                            )),
                          )
                        : null,
                  ),
                if (reviewed)
                  RecruitmentDesignCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '다른 기기에 저장된 최신 목록',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          m.items.isEmpty
                              ? '저장 문구 없음'
                              : m.items.map((r) => r['text']).join('\n'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Text(
                          '확인 후 저장하면 위에 작성한 내용으로 바뀝니다.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                if (m.failure != null)
                  Text(
                    recruitmentFailureMessage(m.failure),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                if (m.failure == 'REVISION_CONFLICT' || needsReview)
                  TextButton(
                    onPressed: editable
                        ? () async {
                            await m.load();
                            if (mounted &&
                                m.scopeKey() == binding &&
                                m.failure == null) {
                              setState(() {
                                version = m.document!.wire['version'] as int;
                                reviewed = true;
                                needsReview = false;
                              });
                            }
                          }
                        : null,
                    child: const Text('작성 내용 유지하고 최신 목록 확인'),
                  ),
                if (m.pending != null) ...[
                  Text(
                    m.pending!.state == RecruitmentCommandState.needsReview
                        ? '오래된 저장 요청입니다. 결과 확인이 필요합니다.'
                        : '문구 저장 결과를 아직 확인하지 못했습니다.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  TextButton(
                    onPressed:
                        !m.saving &&
                            m.pending!.state !=
                                RecruitmentCommandState.needsReview
                        ? () => save(retry: true)
                        : null,
                    child: const Text('같은 저장 요청 다시 확인'),
                  ),
                ],
                const SizedBox(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '저장한 문구를 바꿔도 이미 보낸\n신청 메모는 바뀌지 않아요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                RecruitmentPrimaryButton(
                  label: m.saving ? '저장 중' : '저장',
                  onPressed: editable && valid && !needsReview
                      ? () => save()
                      : null,
                ),
                const SizedBox(height: 12),
                RecruitmentPrimaryButton(
                  label: '취소',
                  secondary: true,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      );
    },
  );
}
