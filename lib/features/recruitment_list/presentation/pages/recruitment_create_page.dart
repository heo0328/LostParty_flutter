import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../account/domain/entities/local_game_account.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/policies/approval_policy.dart';
import '../../domain/policies/party_composition_policy.dart';
import '../../domain/services/recruitment_command_service.dart';

class RecruitmentCreatePage extends StatefulWidget {
  const RecruitmentCreatePage({
    required this.accountRepository,
    required this.catalogRepository,
    required this.commandService,
    super.key,
  });
  final AccountRepository accountRepository;
  final RaidCatalogRepository catalogRepository;
  final RecruitmentCommandService commandService;
  @override
  State<RecruitmentCreatePage> createState() => _RecruitmentCreatePageState();
}

class _RecruitmentCreatePageState extends State<RecruitmentCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _combatPower = TextEditingController();
  final _hours = TextEditingController();
  final _quorum = TextEditingController(text: '2');
  RaidCatalog? _catalog;
  LocalAccountCharacter? _leader;
  RaidDefinition? _raid;
  RaidDifficultyDefinition? _difficulty;
  PartyRole _role = PartyRole.dealer;
  ExperienceLevel _experience = ExperienceLevel.clearExp;
  ApprovalMode _approval = ApprovalMode.leaderOnly;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _combatPower.dispose();
    _hours.dispose();
    _quorum.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.catalogRepository.loadCatalog(),
        widget.accountRepository.loadMainAccount(),
      ]);
      final catalog = results[0] as RaidCatalog;
      final account = results[1] as LocalGameAccount?;
      LocalAccountCharacter? leader;
      if (account != null) {
        for (final character in account.characters) {
          if (character.id == account.representativeCharacterId) {
            leader = character;
          }
        }
      }
      setState(() {
        _catalog = catalog;
        _leader = leader;
        _raid = catalog.raids.where((raid) => raid.isActive).first;
        _difficulty = _raid!.difficulties.where((item) => item.isActive).first;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loadError = '모집 생성 정보를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('모집 만들기')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(child: Text(_loadError!))
        : _leader == null
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('내 계정에서 대표 캐릭터를 먼저 설정해주세요.'),
            ),
          )
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '파티장: ${_leader!.characterName} (${_leader!.characterClassName})',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('recruitmentTitleField'),
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '모집 제목',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '모집 제목을 입력해주세요.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RaidDefinition>(
                  initialValue: _raid,
                  decoration: const InputDecoration(
                    labelText: '레이드',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final raid in _catalog!.raids.where(
                      (item) => item.isActive,
                    ))
                      DropdownMenuItem(
                        value: raid,
                        child: Text(raid.displayName),
                      ),
                  ],
                  onChanged: (raid) => setState(() {
                    _raid = raid;
                    _difficulty = raid!.difficulties
                        .where((item) => item.isActive)
                        .first;
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RaidDifficultyDefinition>(
                  key: ValueKey(_raid!.raidId),
                  initialValue: _difficulty,
                  decoration: const InputDecoration(
                    labelText: '난이도',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in _raid!.difficulties.where(
                      (item) => item.isActive,
                    ))
                      DropdownMenuItem(
                        value: item,
                        child: Text('${item.name} (${item.displayAlias})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _difficulty = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PartyRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: '파티장 역할',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: PartyRole.dealer,
                      child: Text('딜러'),
                    ),
                    DropdownMenuItem(
                      value: PartyRole.support,
                      child: Text('서포터'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _role = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('minCombatPowerField'),
                  controller: _combatPower,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '최소 전투력',
                    border: OutlineInputBorder(),
                  ),
                  validator: _positiveInteger,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExperienceLevel>(
                  initialValue: _experience,
                  decoration: const InputDecoration(
                    labelText: '숙련도',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ExperienceLevel.tryLevel,
                      child: Text('트라이'),
                    ),
                    DropdownMenuItem(
                      value: ExperienceLevel.clearExp,
                      child: Text('클경'),
                    ),
                    DropdownMenuItem(
                      value: ExperienceLevel.multiClearExp,
                      child: Text('다클경'),
                    ),
                    DropdownMenuItem(
                      value: ExperienceLevel.semiExperienced,
                      child: Text('반숙'),
                    ),
                    DropdownMenuItem(
                      value: ExperienceLevel.experienced,
                      child: Text('숙련'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _experience = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '최대 시간 (비우면 클리어 시까지)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null ||
                          value.isEmpty ||
                          (int.tryParse(value) ?? 0) > 0
                      ? null
                      : '1 이상의 시간을 입력해주세요.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ApprovalMode>(
                  initialValue: _approval,
                  decoration: const InputDecoration(
                    labelText: '가입 승인',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ApprovalMode.leaderOnly,
                      child: Text('파티장 승인'),
                    ),
                    DropdownMenuItem(
                      value: ApprovalMode.anyMember,
                      child: Text('파티원 승인'),
                    ),
                    DropdownMenuItem(
                      value: ApprovalMode.quorum,
                      child: Text('정족수 승인'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _approval = value!),
                ),
                if (_approval == ApprovalMode.quorum) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quorum,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '필요 동의 인원',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (int.tryParse(value ?? '') ?? 0) >= 2
                        ? null
                        : '2명 이상을 입력해주세요.',
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('saveRecruitmentButton'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '생성 중...' : '모집 생성'),
                ),
              ],
            ),
          ),
  );
  String? _positiveInteger(String? value) =>
      (int.tryParse(value ?? '') ?? 0) > 0 ? null : '1 이상의 전투력을 입력해주세요.';
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final raid = _raid!;
    final difficulty = _difficulty!;
    final approval = switch (_approval) {
      ApprovalMode.leaderOnly => const ApprovalPolicy.leaderOnly(),
      ApprovalMode.anyMember => const ApprovalPolicy.anyMember(),
      ApprovalMode.quorum => ApprovalPolicy.quorum(
        requiredApprovals: int.parse(_quorum.text),
      ),
    };
    final result = await widget.commandService.createRecruitment(
      title: _title.text.trim(),
      metadata: RecruitmentMetadata(
        catalogVersion: _catalog!.catalogVersion,
        raidId: raid.raidId,
        difficultyId: difficulty.difficultyId,
        raidName: raid.displayName,
        difficultyName: difficulty.name,
        difficultyAlias: difficulty.displayAlias,
        gateCount: raid.gateCount,
        minCombatPower: int.parse(_combatPower.text),
        experienceLevel: _experience,
        maxPlayHours: _hours.text.isEmpty ? null : int.parse(_hours.text),
      ),
      leaderCharacterId: _leader!.characterName,
      leaderClassName: _leader!.characterClassName,
      leaderRole: _role,
      approvalPolicy: approval,
      compositionPolicy: PartyCompositionPolicy(
        RecruitmentPartyRules.fromRaid(raid),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      context.pushReplacement('/recruitments/${result.aggregate!.id}');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모집을 생성하지 못했습니다.')));
    }
  }
}
