import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../recruitment_list/domain/entities/party_read_models.dart';
import '../../../recruitment_list/domain/repositories/party_read_repository.dart';

class PartyReadDetailViewState<T> {
  const PartyReadDetailViewState({
    this.item,
    this.isLoading = true,
    this.isFromCache = false,
    this.failure,
  });

  final T? item;
  final bool isLoading;
  final bool isFromCache;
  final PartyReadFailureType? failure;

  bool get isMissing => !isLoading && failure == null && item == null;

  bool get hasFailureWithItem => failure != null && item != null;
}

/// 단건 모집 읽기 Stream을 구독해 누락·캐시·오류를 목록과 같은 계약으로 표현한다.
class PartyReadDetailViewModel<T> extends ChangeNotifier {
  PartyReadDetailViewModel({
    required Stream<PartyReadDetailSnapshot<T>> Function() streamFactory,
  }) : _streamFactory = streamFactory;

  Stream<PartyReadDetailSnapshot<T>> Function() _streamFactory;
  StreamSubscription<PartyReadDetailSnapshot<T>>? _subscription;
  PartyReadDetailViewState<T> _state = PartyReadDetailViewState<T>();

  PartyReadDetailViewState<T> get state => _state;

  void start() {
    if (_subscription != null) return;
    _subscription = _streamFactory().listen(_onSnapshot, onError: _onError);
  }

  /// 라우트 `recruitmentId` 변경 시 이전 구독을 끊고 새 문서를 구독한다.
  void restart(
    Stream<PartyReadDetailSnapshot<T>> Function() streamFactory,
  ) {
    _subscription?.cancel();
    _subscription = null;
    _streamFactory = streamFactory;
    _state = PartyReadDetailViewState<T>();
    notifyListeners();
    start();
  }

  void _onSnapshot(PartyReadDetailSnapshot<T> snapshot) {
    _state = PartyReadDetailViewState<T>(
      item: snapshot.item,
      isLoading: false,
      isFromCache: snapshot.isFromCache,
    );
    notifyListeners();
  }

  void _onError(Object error) {
    _state = PartyReadDetailViewState<T>(
      item: _state.item,
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
