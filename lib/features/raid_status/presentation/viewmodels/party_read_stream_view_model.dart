import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';

class PartyReadViewState<T> {
  const PartyReadViewState({
    this.items = const [],
    this.isLoading = true,
    this.isFromCache = false,
    this.failure,
  });

  final List<T> items;
  final bool isLoading;
  final bool isFromCache;
  final PartyReadFailureType? failure;

  bool get isEmpty => !isLoading && failure == null && items.isEmpty;

  /// 이미 받은 목록이 있는 상태의 후속 오류는 목록을 지우지 않고 함께 표시한다.
  bool get hasFailureWithItems => failure != null && items.isNotEmpty;
}

/// 실시간 파티 읽기 Stream을 구독해 계약된 loading·빈 상태·오프라인·오류 경계를 표현한다.
class PartyReadStreamViewModel<T> extends ChangeNotifier {
  PartyReadStreamViewModel({
    required Stream<PartyReadSnapshot<T>> Function() streamFactory,
  }) : _streamFactory = streamFactory;

  final Stream<PartyReadSnapshot<T>> Function() _streamFactory;
  StreamSubscription<PartyReadSnapshot<T>>? _subscription;
  PartyReadViewState<T> _state = PartyReadViewState<T>();

  PartyReadViewState<T> get state => _state;

  void start() {
    if (_subscription != null) return;
    _subscription = _streamFactory().listen(
      _onSnapshot,
      onError: _onError,
    );
  }

  void _onSnapshot(PartyReadSnapshot<T> snapshot) {
    _state = PartyReadViewState<T>(
      items: snapshot.items,
      isLoading: false,
      isFromCache: snapshot.isFromCache,
    );
    notifyListeners();
  }

  void _onError(Object error) {
    _state = PartyReadViewState<T>(
      items: _state.items,
      isLoading: false,
      isFromCache: _state.isFromCache,
      failure: error is PartyReadException
          ? error.type
          : PartyReadFailureType.unknown,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
