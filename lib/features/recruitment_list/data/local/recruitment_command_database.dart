import 'package:drift/drift.dart';
part 'recruitment_command_database.g.dart';

class RecruitmentCommandRows extends Table {
  TextColumn get environment => text()();
  TextColumn get userId => text()();
  TextColumn get owner => text()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {environment, userId, owner};
}

/// Separate file and schema: account/ownership databases are untouched.
@DriftDatabase(tables: [RecruitmentCommandRows])
class RecruitmentCommandDatabase extends _$RecruitmentCommandDatabase {
  RecruitmentCommandDatabase(super.executor);
  @override
  int get schemaVersion => 1;
}
