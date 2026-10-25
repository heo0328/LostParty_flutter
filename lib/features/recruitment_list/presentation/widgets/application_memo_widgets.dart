import 'dart:convert';
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
      Widget content() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '공대장에게 한마디',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed:
                    enabled && m?.document != null && !m!.loading && !m.saving
                    ? () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => _PresetsEditor(controller: m),
                      )
                    : null,
                child: const Text('문구 관리'),
              ),
            ],
          ),
          TextField(
            controller: draft.input,
            enabled: enabled,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              hintText: '예: 2관문까지 경험 있어요',
              counterText: '${draft.validation.text.length}/20',
              errorText: draft.composing ? null : draft.validation.error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
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
              '아직 확인하지 못한 문구 저장 요청이 있어요. 문구 관리에서 확인해 주세요.',
              style: TextStyle(fontSize: 11),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final item in m?.items ?? <Map<String, dynamic>>[])
                ActionChip(
                  label: Text(
                    item['text'] as String,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: enabled
                      ? () => draft.select(item['text'] as String)
                      : null,
                ),
            ],
          ),
          if (m?.document != null && m!.items.isEmpty)
            const Text(
              '문구를 저장하면 여기서 바로 선택할 수 있어요.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 12),
        ],
      );
      return m == null
          ? content()
          : ListenableBuilder(listenable: m, builder: (_, _) => content());
    },
  );
}

class _PresetsEditor extends StatefulWidget {
  const _PresetsEditor({required this.controller});
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
    binding = m.scopeKey();
    version = m.document!.wire['version'] as int;
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
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '저장 문구 관리',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: '닫기',
                    ),
                  ],
                ),
                if (!active)
                  const Text('계정이 변경되었습니다. 창을 닫고 다시 열어 주세요.')
                else ...[
                  const Text(
                    '최대 5개 · 문구마다 20자',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              key: ValueKey(row.id),
                              controller: row.input,
                              enabled: editable,
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.text,
                              maxLines: 2,
                              minLines: 1,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: '문구 ${rows.indexOf(row) + 1}',
                                counterText:
                                    '${ApplicationMemoPolicy.check(row.input.text).text.length}/20',
                                errorText:
                                    row.input.value.composing.isValid &&
                                        !row.input.value.composing.isCollapsed
                                    ? null
                                    : ApplicationMemoPolicy.check(
                                        row.input.text,
                                        required: true,
                                      ).error,
                                errorMaxLines: 3,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: editable
                                ? () => setState(() {
                                    rows.remove(row);
                                    row.input.dispose();
                                  })
                                : null,
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.error,
                            ),
                            tooltip: '문구 삭제',
                          ),
                        ],
                      ),
                    ),
                  if (rows.length < 5)
                    OutlinedButton.icon(
                      onPressed: editable
                          ? () => setState(
                              () => rows.add((
                                id: newScopedCommandKey(),
                                input: makeInput(''),
                              )),
                            )
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('문구 추가'),
                    ),
                  if (reviewed) ...[
                    const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: editable && valid && !needsReview
                        ? () => save()
                        : null,
                    child: Text(m.saving ? '저장 중' : '저장'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
