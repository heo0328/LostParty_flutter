import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/presentation/viewmodels/party_read_detail_view_model.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_read_repository.dart';

void main() {
  late StreamController<PartyReadDetailSnapshot<String>> controller;

  setUp(() {
    controller = StreamController<PartyReadDetailSnapshot<String>>();
  });

  tearDown(() => controller.close());

  PartyReadDetailViewModel<String> createViewModel() {
    return PartyReadDetailViewModel<String>(
      streamFactory: () => controller.stream,
    );
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('첫 snapshot 전에는 loading 상태를 유지한다', () {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    expect(viewModel.state.isLoading, isTrue);
    expect(viewModel.state.isMissing, isFalse);
  });

  test('문서 누락은 빈 목록과 구분되는 누락 상태로 표시한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    controller.add(
      const PartyReadDetailSnapshot(item: null, isFromCache: false),
    );
    await settle();

    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.isMissing, isTrue);
    expect(viewModel.state.failure, isNull);
  });

  test('캐시 snapshot은 문서와 오프라인 여부를 함께 전달한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    controller.add(
      const PartyReadDetailSnapshot(item: 'room', isFromCache: true),
    );
    await settle();

    expect(viewModel.state.item, 'room');
    expect(viewModel.state.isFromCache, isTrue);
    expect(viewModel.state.isMissing, isFalse);
  });

  test('문서 없이 발생한 오류는 실패 유형으로 구분한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    controller.addError(
      const PartyReadException(PartyReadFailureType.permissionDenied),
    );
    await settle();

    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.failure, PartyReadFailureType.permissionDenied);
    expect(viewModel.state.item, isNull);
  });

  test('이미 받은 문서가 있으면 후속 오류에도 내용을 지우지 않는다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    controller.add(
      const PartyReadDetailSnapshot(item: 'room', isFromCache: false),
    );
    await settle();
    controller.addError(
      const PartyReadException(PartyReadFailureType.unavailable),
    );
    await settle();

    expect(viewModel.state.item, 'room');
    expect(viewModel.state.hasFailureWithItem, isTrue);
  });
}
