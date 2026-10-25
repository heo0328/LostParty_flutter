import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../../account/domain/scoped_cache_models.dart';
import '../local/recruitment_command_database.dart';
import 'recruitment_command.dart';

abstract interface class RecruitmentCommandStore {
  Future<RecruitmentCommand?> read(
    StorageScope scope,
    RecruitmentCommandOwner owner,
  );
  Future<void> insert(StorageScope scope, RecruitmentCommand command);
  Future<void> replace(StorageScope scope, RecruitmentCommand command);
  Future<void> releaseResolved(
    StorageScope scope,
    RecruitmentCommandOwner owner,
    String key,
  );
  Future<void> close();
}

class DriftRecruitmentCommandStore implements RecruitmentCommandStore {
  DriftRecruitmentCommandStore({
    RecruitmentCommandDatabase Function()? databaseFactory,
  }) : _factory =
           databaseFactory ??
           (() => RecruitmentCommandDatabase(
             driftDatabase(name: 'lost_party_recruitment_commands'),
           ));
  final RecruitmentCommandDatabase Function() _factory;
  RecruitmentCommandDatabase? _opened;
  bool _closed = false;
  RecruitmentCommandDatabase get _db {
    if (_closed) throw StateError('Recruitment store disposed');
    return _opened ??= _factory();
  }

  @override
  Future<RecruitmentCommand?> read(
    StorageScope scope,
    RecruitmentCommandOwner owner,
  ) async {
    final db = _db;
    final row =
        await (db.select(db.recruitmentCommandRows)..where(
              (r) =>
                  r.environment.equals(scope.environment) &
                  r.userId.equals(scope.userId) &
                  r.owner.equals(owner.name),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final command = RecruitmentCommand.decode(row.payload);
    if (command.owner != owner) {
      throw const FormatException('Corrupt recruitment journal');
    }
    return command;
  }

  @override
  Future<void> insert(StorageScope scope, RecruitmentCommand command) async {
    if (command.state != RecruitmentCommandState.pending ||
        command.attemptedAt != null) {
      throw StateError('Only a new pending request may be inserted');
    }
    await _db
        .into(_db.recruitmentCommandRows)
        .insert(
          RecruitmentCommandRowsCompanion.insert(
            environment: scope.environment,
            userId: scope.userId,
            owner: command.owner.name,
            payload: command.encode(),
          ),
        );
  }

  @override
  Future<void> replace(StorageScope scope, RecruitmentCommand command) async {
    // Transaction + same original key prevents an old completion overwriting a new request.
    final db = _db;
    await db.transaction(() async {
      final old = await read(scope, command.owner);
      if (old == null ||
          !old.sameOriginal(command) ||
          (old.state == RecruitmentCommandState.acknowledged &&
              (command.state != old.state || command.rawAck != old.rawAck)) ||
          (old.state == RecruitmentCommandState.rejected &&
              command.encode() != old.encode()) ||
          (old.state == RecruitmentCommandState.needsReview &&
              command.state == RecruitmentCommandState.pending)) {
        throw StateError('Recruitment request changed');
      }
      await (db.update(db.recruitmentCommandRows)..where(
            (r) =>
                r.environment.equals(scope.environment) &
                r.userId.equals(scope.userId) &
                r.owner.equals(command.owner.name),
          ))
          .write(
            RecruitmentCommandRowsCompanion(payload: Value(command.encode())),
          );
    });
  }

  @override
  Future<void> releaseResolved(
    StorageScope scope,
    RecruitmentCommandOwner owner,
    String key,
  ) async {
    final db = _db;
    await db.transaction(() async {
      final old = await read(scope, owner);
      if (old == null ||
          old.key != key ||
          !{
            RecruitmentCommandState.acknowledged,
            RecruitmentCommandState.rejected,
          }.contains(old.state)) {
        throw StateError('Only resolved requests may be released');
      }
      await (db.delete(db.recruitmentCommandRows)..where(
            (r) =>
                r.environment.equals(scope.environment) &
                r.userId.equals(scope.userId) &
                r.owner.equals(owner.name),
          ))
          .go();
    });
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _opened?.close();
  }
}
