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
import 'package:postgres/postgres.dart' hide Type;

/// Postgres driver for Archery ORM.
///
/// This class provides static helpers for:
/// - registering model constructors for hydration (`migrate<T>()`)
/// - creating tables/indexes for models
/// - executing CRUD operations against a [PostgresDatabase] connection
///
/// Models are discovered/registered by calling `PostgresModel.migrate<T>()`
/// with a constructor (and optional column definitions).
abstract class PostgresModel {
  static PostgresDatabase get _database => App().make<PostgresDatabase>();

  static Uuid get _uuid => App().make<Uuid>();

  static final Map<Type, Function> _jsonConstructors = {};

  static Map<Type, Function> get migrations => _jsonConstructors;

  static final Map<String, String> _columnDefinitions = {
    'id': 'SERIAL PRIMARY KEY',
    'uuid': 'UUID UNIQUE',
    'created_at': 'TIMESTAMPTZ',
    'updated_at': 'TIMESTAMPTZ',
  };

  static String _getTableName<T>() {
    final typeName = T.toString();
    final snakeCase = typeName.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (match) => '_',
    );
    return '${snakeCase.toLowerCase()}s';
  }

  static Future<void> migrate<T extends Model>({
    required T Function(Map<String, dynamic>) constructor,
    Map<String, String>? columnDefinitions,
  }) async {
    _jsonConstructors[T] = constructor;

    try {
      if (columnDefinitions != null && columnDefinitions.isNotEmpty) {
        final tableName = _getTableName<T>();
        final allColumns = {..._columnDefinitions, ...columnDefinitions};

        final columnsDef = allColumns.entries
            .map((e) => '${e.key} ${e.value}')
            .join(', ');

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
    } catch (e, s) {
      App().archeryLogger.error("Migration Error", {
        "origin": "PostgresModel.migrate",
        "error": e.toString(),
        "stack": s.toString(),
      });
    }
  }

  static Future<List<Map<String, dynamic>>> jsonIndex<T extends Model>() async {
    try {
      final tableName = _getTableName<T>();
      final results = await _database.execute(
        Sql('SELECT * FROM "$tableName" ORDER BY id DESC'),
      );

      List<Map<String, dynamic>> records = [];

      if (results.isNotEmpty) {
        for (final row in results) {
          final Map<String, dynamic> rowAsMap = row.toColumnMap();
          records.add(rowAsMap);
        }
        return records;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> _create<T extends Model>(T instance) async {
    try {
      final tableName = _getTableName<T>();

      instance.uuid = _uuid.v4();
      instance.createdAt = DateTime.now().toUtc();
      instance.updatedAt = DateTime.now().toUtc();

      final data = instance.toMetaJson();
      data.remove('id');

      final columns = data.keys.join(', ');
      final placeholders = List.generate(
        data.length,
        (i) => '@${data.keys.elementAt(i)}',
      ).join(', ');

      final result = await _database.execute(
        Sql.named('''
        INSERT INTO $tableName ($columns) 
        VALUES ($placeholders) 
        RETURNING id
        '''),
        parameters: data,
      );

      if (result.isNotEmpty) {
        instance.id = result.first.toColumnMap()['id'] as int;
        return true;
      }
      return false;
    } catch (e) {
      print('Postgres create error: $e');
      return false;
    }
  }

  static Future<bool> _update<T extends Model>(T instance) async {
    if (instance.id == null) return false;

    try {
      final tableName = _getTableName<T>();
      instance.updatedAt = DateTime.now().toUtc();

      final data = {
        ...instance.toMetaJson(),
        'updated_at': instance.updatedAt!.toIso8601String(),
      };

      final updates = data.keys.map((key) => '$key = @$key').join(', ');

      final result = await _database.execute(
        Sql.named('''
        UPDATE $tableName 
        SET $updates 
        WHERE id = @id
      '''),
        parameters: {...data, 'id': instance.id},
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Postgres update error: $e');
      return false;
    }
  }

  static Future<List<T>> all<T extends Model>() async => index<T>();

  static Future<List<T>> index<T extends Model>() async {
    try {
      final constructor = _jsonConstructors[T];
      if (constructor == null) return [];

      final records = await jsonIndex<T>();

      if (records.isNotEmpty) {
        return records.map((record) => constructor(record) as T).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<int> count<T extends Model>() async {
    try {
      final tableName = _getTableName<T>();
      final result = await _database.execute(
        'SELECT COUNT(*) FROM "$tableName"',
      );
      return result.first[0] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<bool> delete<T extends Model>({required int id}) async {
    try {
      final tableName = _getTableName<T>();
      final result = await _database.execute(
        Sql.named('DELETE FROM "$tableName" WHERE id = @id RETURNING *'),
        parameters: {'id': id},
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Postgres delete error: $e');
      return false;
    }
  }

  static Future<T?> find<T extends Model>({required int id}) async {
    try {
      final constructor = _jsonConstructors[T];
      if (constructor == null) return null;

      final tableName = _getTableName<T>();

      final result = await _database.execute(
        Sql.named('SELECT * FROM "$tableName" WHERE id = @id LIMIT 1'),
        parameters: {'id': id},
      );

      if (result.isNotEmpty) {
        return constructor(result.first.toColumnMap()) as T;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<T?> findBy<T extends Model>({
    required String field,
    required dynamic value,
  }) async {
    try {
      final constructor = _jsonConstructors[T];
      if (constructor == null) return null;

      final tableName = _getTableName<T>();

      final records = await _database.execute(
        Sql.named('SELECT * FROM "$tableName" WHERE $field = @$field LIMIT 1'),
        parameters: {field: value},
      );

      if (records.isNotEmpty) {
        return constructor(records.first.toColumnMap()) as T;
      }
      return null;
    } catch (e) {
      print('Postgres findBy error: $e');
      return null;
    }
  }

  static Future<T?> findByUUID<T extends Model>(String uuid) async {
    try {
      final constructor = _jsonConstructors[T];
      if (constructor == null) return null;

      final tableName = _getTableName<T>();
      final result = await _database.execute(
        Sql.named('SELECT * FROM "$tableName" WHERE uuid = @uuid LIMIT 1'),
        parameters: {'uuid': uuid},
      );

      if (result.isNotEmpty) {
        return constructor(result.first.toColumnMap());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<T>> where<T extends Model>({
    required String field,
    String comp = "==",
    required dynamic value,
  }) async {
    try {
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

      final tableName = _getTableName<T>();
      final records = await _database.execute(
        Sql.named('SELECT * FROM "$tableName" WHERE $field = @$field'),
        parameters: {field: value},
      );

      if (records.isNotEmpty) {
        return records
            .map((record) => constructor(record.toColumnMap()) as T)
            .toList();
      }

      return [];
    } catch (e) {
      print('Postgres where error: $e');
      return [];
    }
  }

  static Future<T?> firstWhere<T extends Model>({
    required String field,
    String comp = "==",
    required dynamic value,
  }) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

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
      final tableName = _getTableName<T>();
      final record = await _database.execute(
        Sql.named('SELECT * FROM "$tableName" WHERE $field = @$field LIMIT 1'),
        parameters: {field: value},
      );

      if (record.isNotEmpty) {
        return constructor(record.first.toColumnMap()) as T;
      }

      return null;
    } catch (e) {
      print('Postgres where error: $e');
      return null;
    }
  }

  static Future<T?> create<T extends Model>(
    Map<String, dynamic> fromJson,
  ) async {
    try {
      final constructor = _jsonConstructors[T];
      if (constructor == null) return null;

      fromJson
        ..remove('id')
        ..remove('uuid')
        ..remove('created_at')
        ..remove('updated_at');

      final defaults = {
        'uuid': _uuid.v4(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final instance = constructor({...fromJson, ...defaults}) as T;

      if (await instance.save(disk: .pgsql)) {
        return instance;
      }
      return null;
    } catch (e) {
      print('Postgres create error: $e');
      return null;
    }
  }

  /// Saves [instance] (create or update).
  static Future<bool> save<T extends Model>(T instance) async {
    if (instance.id == null || instance.createdAt == null) {
      return await _create<T>(instance);
    } else {
      return await _update<T>(instance);
    }
  }

  static Future<bool> exists<T extends Model>({required int id}) async {
    return await find<T>(id: id) != null;
  }

  static Future<bool> truncate<T extends Model>() async {
    try {
      final tableName = _getTableName<T>();
      await _database.execute(
        Sql.named('TRUNCATE TABLE "$tableName" RESTART IDENTITY CASCADE'),
      );
      return true;
    } catch (e) {
      print('Postgres truncate error: $e');
      return false;
    }
  }

  static Future<bool> updateInstance<T extends Model>({
    required T instance,
    required Map<String, dynamic> withJson,
  }) async {
    try {
      final constructor = _jsonConstructors[T];
      if (constructor == null) return false;
      withJson
        ..remove('id')
        ..remove('uuid')
        ..remove('created_at');

      final current = instance.toMetaJson()..addAll(withJson);
      final updated = constructor(current) as T;

      return await _update<T>(updated);
    } catch (e) {
      print('Postgres updateInstance error: $e');
      return false;
    }
  }

  static Future<bool> update<T extends Model>({
    required dynamic id,
    required String field,
    required dynamic value,
  }) async {
    try {
      final instance = await find<T>(id: id);
      if (instance == null) return false;

      final json = instance.toMetaJson()..[field] = value;
      final constructor = _jsonConstructors[T]!;

      final updated = constructor(json) as T;

      return await _update<T>(updated);
    } catch (e) {
      return false;
    }
  }
}
