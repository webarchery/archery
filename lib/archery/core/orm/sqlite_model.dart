// SPDX-FileCopyrightText: 2025 Kwame, III <webarcherydev@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// https://webarchery.dev

import 'package:archery/archery/archery.dart';

/// SQLite persistence backend for `Model`.
///
/// **Features:**
/// - Full CRUD with type-safe model instantiation
/// - Automatic table creation via `migrate<T>()`
/// - UUID + timestamp handling
/// - Indexes on `uuid` and `created_at`
/// - Safe mass-assignment protection
/// - Query builder (`where`, `firstWhere`)
///
/// **Usage:**
/// ```dart
/// // Define model
/// class User extends Model {
///   String name;
///   String email;
///
///   User({this.name = '', this.email = ''});
///
///   @override
///   Map<String, dynamic> toJson() => {'name': name, 'email': email};
///
///   @override
///   Map<String, dynamic> toMetaJson() => {
///     'id': id,
///     'uuid': uuid,
///     'created_at': createdAt?.toIso8601String(),
///     'updated_at': updatedAt?.toIso8601String(),
///   };
///
///   User.fromJson(Map<String, dynamic> json)
///       : name = json['name'],
///         email = json['email'],
///         super.fromJson(json);
/// }
///
/// // Register model and schema
/// await SQLiteModel.migrate<User>(
///   constructor: (json) => User.fromJson(json),
///   columnDefinitions: {
///     'name': 'TEXT NOT NULL',
///     'email': 'TEXT UNIQUE NOT NULL',
///   },
/// );
/// ```
abstract class SQLiteModel {
  /// Access to the singleton `Database` instance.
  static Database get _database => App().make<Database>();

  /// UUID generator from DI container.
  static Uuid get _uuid => App().make<Uuid>();

  /// Registry of model constructors: `Type → (Map → T)`.
  static final Map<Type, Function> _jsonConstructors = {};

  /// Public access to constructor registry.
  static Map<Type, Function> get migrations => _jsonConstructors;

  /// Default column definitions for all models.
  static final Map<String, String> _columnDefinitions = {'id': 'INTEGER PRIMARY KEY AUTOINCREMENT', 'uuid': 'TEXT UNIQUE NOT NULL', 'created_at': 'TEXT NOT NULL', 'updated_at': 'TEXT NOT NULL'};

  /// Converts `UserModel` → `user_models` (snake_case plural).
  static String _getTableName<T>() {
    final typeName = T.toString();
    final snakeCase = typeName.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (match) => '_');
    return '${snakeCase.toLowerCase()}s';
  }

  /// Creates a new record with auto-generated UUID and timestamps.
  static Future<bool> _create<T extends Model>(T instance) async {
    final tableName = _getTableName<T>();
    instance.uuid = _uuid.v4();
    instance.createdAt = DateTime.now().toUtc();
    instance.updatedAt = DateTime.now().toUtc();

    try {
      final data = {...instance.toJson(), ...instance.toMetaJson(), 'uuid': instance.uuid, 'created_at': instance.createdAt!.toIso8601String(), 'updated_at': instance.updatedAt!.toIso8601String()};

      final id = await _database.insert(tableName, data);
      if (id > 0) {
        instance.id = id;
        return true;
      }
      return false;
    } catch (e) {
      print('SQLite create error: $e');
      return false;
    }
  }

  /// Updates an existing record by `id`.
  static Future<bool> _update<T extends Model>(T instance) async {
    if (instance.id == null) return false;

    try {
      final tableName = _getTableName<T>();
      instance.updatedAt = DateTime.now().toUtc();

      final data = {...instance.toJson(), 'updated_at': instance.updatedAt!.toIso8601String()};

      final rows = await _database.update(tableName, data, where: 'id = ?', whereArgs: [instance.id]);

      return rows > 0;
    } catch (e) {
      print('SQLite update error: $e');
      return false;
    }
  }

  /// Registers a model with schema and constructor.
  ///
  /// **Must be called before any CRUD operations.**
  ///
  /// - [constructor]: `(Map<String, dynamic>) → T`
  /// - [columnDefinitions]: Custom columns (merged with defaults)
  ///
  /// Example:
  /// ```dart
  /// await SQLiteModel.migrate<User>(
  ///   constructor: (json) => User.fromJson(json),
  ///   columnDefinitions: {
  ///     'name': 'TEXT NOT NULL',
  ///     'email': 'TEXT UNIQUE NOT NULL',
  ///   },
  /// );
  /// ```
  static Future<void> migrate<T extends Model>({required T Function(Map<String, dynamic>) constructor, Map<String, String>? columnDefinitions}) async {
    _jsonConstructors[T] = constructor;

    if (columnDefinitions != null && columnDefinitions.isNotEmpty) {
      final tableName = _getTableName<T>();
      final allColumns = {..._columnDefinitions, ...columnDefinitions};

      final columnsDef = allColumns.entries.map((e) => '${e.key} ${e.value}').join(', ');

      await _database.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          $columnsDef
        )
      ''');

      // Performance indexes
      await _database.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_uuid 
        ON $tableName (uuid)
      ''');

      await _database.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_created_at 
        ON $tableName (created_at)
      ''');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // CRUD Operations
  // ──────────────────────────────────────────────────────────────────────

  /// Alias for `index<T>()`.
  static Future<List<T>> all<T extends Model>() async => index<T>();

  /// Retrieves all records (ordered by `id DESC`).
  static Future<List<T>> index<T extends Model>() async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return [];

    try {
      final maps = await _database.query(_getTableName<T>(), orderBy: 'id DESC');
      return maps.map((map) => constructor(map) as T).toList();
    } catch (e) {
      print('SQLite index error: $e');
      return [];
    }
  }

  /// Counts total records.
  static Future<int> count<T extends Model>() async {
    try {
      final result = await _database.rawQuery('SELECT COUNT(*) as count FROM ${_getTableName<T>()}');
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Checks if record with [id] exists.
  static Future<bool> exists<T extends Model>({required int id}) async {
    return await find<T>(id: id) != null;
  }

  /// Finds record by primary key (`id`).
  static Future<T?> find<T extends Model>({required int id}) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

    try {
      final maps = await _database.query(_getTableName<T>(), where: 'id = ?', whereArgs: [id], limit: 1);

      if (maps.isNotEmpty) {
        return constructor(maps.first) as T;
      }
      return null;
    } catch (e) {
      print('SQLite find error: $e');
      return null;
    }
  }

  /// Finds first record where [field] == [value].
  static Future<T?> findBy<T extends Model>({required String field, required dynamic value}) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

    try {
      final maps = await _database.query(_getTableName<T>(), where: '$field = ?', whereArgs: [value], limit: 1);

      if (maps.isNotEmpty) {
        return constructor(maps.first) as T;
      }
      return null;
    } catch (e) {
      print('SQLite findBy error: $e');
      return null;
    }
  }

  /// Finds record by `uuid`.
  static Future<T?> findByUUID<T extends Model>(String uuid) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

    try {
      final maps = await _database.query(_getTableName<T>(), where: 'uuid = ?', whereArgs: [uuid], limit: 1);

      if (maps.isNotEmpty) {
        return constructor(maps.first) as T;
      }
      return null;
    } catch (e) {
      print('SQLite findByUUID error: $e');
      return null;
    }
  }

  /// Filters records with comparison.
  ///
  /// Supported: `==`, `!=`, `>`, `<`, `>=`, `<=`
  static Future<List<T>> where<T extends Model>({required String field, String comp = "==", required dynamic value}) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return [];

    const allowedOps = ['=', '==', '!=', '<', '>', '<=', '>=', 'LIKE'];
    if (!allowedOps.contains(comp.toUpperCase()) && comp != "==") {
      // Todo- Look out for quirks / inconsistent results before changing
      // "==" is usually handled as "=" in SQL or logic
      // Adjust logic if "==" is strictly Dart side or SQL side. SQLite uses "=".
      if (comp == "==") {
        comp = "=";
      } else {
        throw ArgumentError("Invalid SQL operator: $comp");
      }
    } else if (comp == "==") {
      comp = "=";
    }

    try {
      final maps = await _database.query(_getTableName<T>(), where: '$field $comp ?', whereArgs: [value]);

      return maps.map((map) => constructor(map) as T).toList();
    } catch (e) {
      print('SQLite where error: $e');
      return [];
    }
  }

  /// Returns first record matching `where()` condition.
  static Future<T?> firstWhere<T extends Model>({required String field, String comp = "==", required dynamic value}) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

    const allowedOps = ['=', '==', '!=', '<', '>', '<=', '>=', 'LIKE'];
    if (!allowedOps.contains(comp.toUpperCase()) && comp != "==") {
      if (comp == "==") {
        comp = "=";
      } else {
        throw ArgumentError("Invalid SQL operator: $comp");
      }
    } else if (comp == "==") {
      comp = "=";
    }

    try {
      final maps = await _database.query(_getTableName<T>(), where: '$field $comp ?', whereArgs: [value], limit: 1);

      if (maps.isNotEmpty) {
        return constructor(maps.first) as T;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Creates a new record from [fromJson].
  ///
  /// Prevents mass-assignment of `id`, `uuid`, timestamps.
  static Future<T?> create<T extends Model>(Map<String, dynamic> fromJson) async {

    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

    try {
      // Prevent injection of protected fields
      fromJson
        ..remove('id')
        ..remove('uuid')
        ..remove('created_at')
        ..remove('updated_at');

      final defaults = {'uuid': _uuid.v4(), 'created_at': DateTime.now().toUtc().toIso8601String(), 'updated_at': DateTime.now().toUtc().toIso8601String()};

      final instance = constructor({...fromJson, ...defaults}) as T;

      if (await instance.save()) {
        return instance;
      }
      return null;
    } catch (e) {
      print('SQLite create error: $e');
      return null;
    }
  }

  /// Saves [instance] (create or update).
  static Future<bool> save<T extends Model>(T instance) async {
    return instance.id == null ? await _create<T>(instance) : await _update<T>(instance);
  }

  /// Updates a single field by `id`.
  static Future<bool> update<T extends Model>({required dynamic id, required String field, required dynamic value}) async {
    final instance = await find<T>(id: id);
    if (instance == null) return false;

    final json = instance.toMetaJson()..[field] = value;
    final constructor = _jsonConstructors[T]!;
    final updated = constructor(json) as T;

    return await _update<T>(updated);
  }

  /// Deletes record by `id`.
  static Future<bool> delete<T extends Model>(dynamic id) async {
    if (id == null) return false;

    try {
      final rows = await _database.delete(_getTableName<T>(), where: 'id = ?', whereArgs: [id]);
      return rows > 0;
    } catch (e) {
      print('SQLite delete error: $e');
      return false;
    }
  }

  /// Updates instance with partial data.
  static Future<bool> updateInstance<T extends Model>({required T instance, required Map<String, dynamic> withJson}) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return false;

    try {
      withJson
        ..remove('id')
        ..remove('uuid');

      final current = instance.toMetaJson()..addAll(withJson);
      final updated = constructor(current) as T;

      return await _update<T>(updated);
    } catch (e) {
      print('SQLite updateInstance error: $e');
      return false;
    }
  }

  /// Deletes first record matching condition.
  static Future<bool> deleteBy<T extends Model>({required String field, required dynamic value}) async {
    final record = await firstWhere<T>(field: field, value: value);
    if (record == null) return false;

    return await record.delete();
  }

  /// Deletes all records in table.
  static Future<bool> truncate<T extends Model>() async {
    try {
      await _database.delete(_getTableName<T>());
      return true;
    } catch (e) {
      print('SQLite truncate error: $e');
      return false;
    }
  }
}
