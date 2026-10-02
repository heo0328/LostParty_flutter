import 'dart:async';
import '../../domain/entities/weekly_raid_status_projection.dart';
import '../../domain/services/ownership_record_visibility.dart';

typedef OwnershipDocumentWatch =
    Stream<Map<String, dynamic>?> Function(String path);

/// Holds results until every required authority has arrived. Removed subscriptions
/// cannot publish late events into a newer dependency set.
Stream<List<WeeklyRaidStatusRecord>> watchCurrentOwnershipRecords(
  Stream<List<WeeklyRaidStatusRecord>> source,
  OwnershipDocumentWatch watch,
) {
  late final StreamController<List<WeeklyRaidStatusRecord>> output;
  StreamSubscription<List<WeeklyRaidStatusRecord>>? sourceSub;
  final entries = <String, _AuthorityEntry>{};
  List<WeeklyRaidStatusRecord>? records;
  var closed = false;
  void fail(Object error, StackTrace stack) {
    if (!closed) output.addError(error, stack);
  }

  late void Function() refresh;
  void subscribe(String path) {
    if (entries.containsKey(path)) return;
    final entry = _AuthorityEntry();
    entries[path] = entry;
    entry.subscription = watch(path).listen(
      (data) {
        if (closed || !identical(entries[path], entry)) return;
        entry.data = data;
        entry.ready = true;
        refresh();
      },
      onError: (Object error, StackTrace stack) {
        if (closed || !identical(entries[path], entry)) return;
        entry.ready = false;
        fail(error, stack);
      },
    );
  }

  refresh = () {
    if (closed || records == null) return;
    final needed = <String>{
      for (final r in records!) 'characters/${r.characterId}',
    };
    for (final path in needed.toList()) {
      subscribe(path);
      final accountId = entries[path]!.data?['gameAccountId'];
      if (accountId is String && accountId.isNotEmpty) {
        needed.add('gameAccounts/$accountId');
      }
    }
    for (final path in needed) {
      subscribe(path);
    }
    for (final path
        in entries.keys.where((p) => !needed.contains(p)).toList()) {
      final removed = entries.remove(path)!;
      unawaited(removed.subscription?.cancel());
    }
    if (needed.any((p) => !entries[p]!.ready)) return;
    try {
      final current = records!
          .where((r) {
            final character = entries['characters/${r.characterId}']!.data;
            return isCurrentOwnershipRecord(
              playerId: r.playerId,
              revision: r.ownershipRevision,
              character: character,
              account:
                  entries['gameAccounts/${character?['gameAccountId']}']?.data,
            );
          })
          .toList(growable: false);
      output.add(current);
    } catch (error, stack) {
      fail(error, stack);
    }
  };
  output = StreamController<List<WeeklyRaidStatusRecord>>(
    onListen: () {
      sourceSub = source.listen(
        (value) {
          records = value;
          refresh();
        },
        onError: (Object error, StackTrace stack) {
          records = null;
          fail(error, stack);
        },
      );
    },
    onCancel: () async {
      closed = true;
      await sourceSub?.cancel();
      await Future.wait(
        entries.values.map((e) async {
          await e.subscription?.cancel();
        }),
      );
      entries.clear();
    },
  );
  return output.stream;
}

class _AuthorityEntry {
  StreamSubscription<Map<String, dynamic>?>? subscription;
  Map<String, dynamic>? data;
  bool ready = false;
}
