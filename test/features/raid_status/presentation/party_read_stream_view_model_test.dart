import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/presentation/viewmodels/party_read_stream_view_model.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_read_repository.dart';

void main() {
  late StreamController<PartyReadSnapshot<String>> controller;
  var subscriptions = 0;

  setUp(() {
    subscriptions = 0;
    controller = StreamController<PartyReadSnapshot<String>>();
  });

  tearDown(() => controller.close());

  PartyReadStreamViewModel<String> createViewModel() {
    return PartyReadStreamViewModel<String>(
      streamFactory: () {
        subscriptions += 1;
        return controller.stream;
      },
    );
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('첫 snapshot 전에는 loading 상태를 유지한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    expect(viewModel.state.isLoading, isTrue);
    expect(viewModel.state.isEmpty, isFalse);
    expect(viewModel.state.failure, isNull);
  });

  test('첫 snapshot이 빈 목록이면 빈 상태로 구분한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    controller.add(const PartyReadSnapshot(items: [], isFromCache: false));
    await settle();

    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.isEmpty, isTrue);
  });

  test('캐시 snapshot은 정상 목록으로 제공하며 오프라인 여부를 함께 전달한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    controller.add(const PartyReadSnapshot(items: ['a'], isFromCache: true));
    await settle();

    expect(viewModel.state.items, ['a']);
    expect(viewModel.state.isFromCache, isTrue);
    expect(viewModel.state.isEmpty, isFalse);
  });

  test('목록 없이 발생한 오류는 실패 유형으로 구분한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    controller.addError(
      const PartyReadException(PartyReadFailureType.permissionDenied),
    );
    await settle();

    expect(viewModel.state.isLoading, isFalse);
    expect(viewModel.state.failure, PartyReadFailureType.permissionDenied);
    expect(viewModel.state.items, isEmpty);
  });

  test('기존 목록이 있으면 후속 오류에도 목록을 지우지 않는다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    controller.add(const PartyReadSnapshot(items: ['a'], isFromCache: false));
    await settle();
    controller.addError(
      const PartyReadException(PartyReadFailureType.unavailable),
    );
    await settle();

    expect(viewModel.state.items, ['a']);
    expect(viewModel.state.failure, PartyReadFailureType.unavailable);
    expect(viewModel.state.hasFailureWithItems, isTrue);
  });

  test('계약 밖 오류는 unknown으로 정규화한다', () async {
    final viewModel = createViewModel()..start();
    addTearDown(viewModel.dispose);

    controller.addError(StateError('unexpected'));
    await settle();

    expect(viewModel.state.failure, PartyReadFailureType.unknown);
  });

  test('start를 반복 호출해도 구독을 하나만 만든다', () async {
    final viewModel = createViewModel()
      ..start()
      ..start();
    addTearDown(viewModel.dispose);

    expect(subscriptions, 1);
  });
}
