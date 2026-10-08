class DatabaseColumn {
  final String name;
  final String type;
  final bool primaryKey;
  final bool nullable;
  final String? references;

  const DatabaseColumn({
    required this.name,
    required this.type,
    this.primaryKey = false,
    this.nullable = false,
    this.references,
  });
}

class DatabaseTable {
  final String name;
  final List<DatabaseColumn> columns;
  final List<List<String>> uniqueConstraints;

  const DatabaseTable({
    required this.name,
    required this.columns,
    this.uniqueConstraints = const [],
  });
}

/// Relational schema contract used by the local store and future backend.
class PartTimeNowSchema {
  static const user = DatabaseTable(
    name: 'User',
    columns: [
      DatabaseColumn(name: 'id', type: 'UUID', primaryKey: true),
      DatabaseColumn(name: 'username', type: 'VARCHAR'),
      DatabaseColumn(name: 'email', type: 'VARCHAR'),
      DatabaseColumn(name: 'password', type: 'VARCHAR'),
      DatabaseColumn(name: 'role', type: 'VARCHAR'),
    ],
  );

  static const job = DatabaseTable(
    name: 'Job',
    columns: [
      DatabaseColumn(name: 'id', type: 'UUID', primaryKey: true),
      DatabaseColumn(name: 'employer_id', type: 'UUID', references: 'User.id'),
      DatabaseColumn(name: 'title', type: 'VARCHAR'),
      DatabaseColumn(name: 'description', type: 'TEXT'),
      DatabaseColumn(name: 'location', type: 'VARCHAR'),
      DatabaseColumn(name: 'salary', type: 'DECIMAL'),
      DatabaseColumn(name: 'requirements', type: 'TEXT'),
      DatabaseColumn(name: 'created_at', type: 'DATETIME'),
    ],
  );

  static const application = DatabaseTable(
    name: 'Application',
    columns: [
      DatabaseColumn(name: 'id', type: 'UUID', primaryKey: true),
      DatabaseColumn(name: 'user_id', type: 'UUID', references: 'User.id'),
      DatabaseColumn(name: 'job_id', type: 'UUID', references: 'Job.id'),
      DatabaseColumn(name: 'cover_letter', type: 'TEXT'),
      DatabaseColumn(name: 'status', type: 'VARCHAR'),
      DatabaseColumn(name: 'applied_at', type: 'DATETIME'),
    ],
    uniqueConstraints: [
      ['user_id', 'job_id'],
    ],
  );

  static const savedJob = DatabaseTable(
    name: 'SavedJob',
    columns: [
      DatabaseColumn(name: 'id', type: 'UUID', primaryKey: true),
      DatabaseColumn(name: 'user_id', type: 'UUID', references: 'User.id'),
      DatabaseColumn(name: 'job_id', type: 'UUID', references: 'Job.id'),
      DatabaseColumn(name: 'saved_at', type: 'DATETIME'),
    ],
    uniqueConstraints: [
      ['user_id', 'job_id'],
    ],
  );

  static const tables = [user, job, application, savedJob];
}
