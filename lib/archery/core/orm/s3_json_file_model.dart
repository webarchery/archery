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

abstract class S3JsonFileModel {
  static S3Client get _s3client => App().make<S3Client>();
  static AppConfig get _config => App().make<AppConfig>();

  static Uuid get _uuid => App().make<Uuid>();

  /// Registry of model constructors: `Type → (Map → T)`.
  ///
  /// Populated via `migrate<T>()`.
  static final Map<Type, Function> _jsonConstructors = {};

  /// Public access to constructor registry (for migrations).
  static Map<Type, Function> get migrations => _jsonConstructors;

  /// Converts `UserModel` → `user_models` (snake_case plural).
  static String _getTableName<T>() {
    final typeName = T.toString();
    final upperSnakeCase = typeName.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (match) => '_');
    return "${upperSnakeCase.toLowerCase()}s";
  }

  // s3 path key for model data
  static String _getS3TableKey<T>() {
    final tableName = _getTableName<T>();
    return "archery/web/app-${_config.get('app.id', _uuid.v4())}/storage/s3_json_file_models/$tableName.json";
  }

  /// Creates a new record with UUID and timestamps.
  static Future<bool> _create<T extends Model>(T instance) async {
    instance.uuid = _uuid.v4();
    instance.createdAt = DateTime.now().toUtc();
    instance.updatedAt = DateTime.now().toUtc();
    return await _saveToS3<T>(instance);
  }

  /// Updates an existing record (updates `updatedAt`).
  static Future<bool> _update<T extends Model>(T instance) async {
    instance.updatedAt = DateTime.now().toUtc();
    return await _saveToS3<T>(instance);
  }

  /// Prepares model for JSON storage: merges data + metadata.
  static Map<String, dynamic> _prepareForSave<T extends Model>(T instance) {
    final data = instance.toJson();
    final meta = instance.toMetaJson();

    return {...data, ...meta, 'uuid': instance.uuid, 'created_at': instance.createdAt?.toIso8601String(), 'updated_at': instance.updatedAt?.toIso8601String()};
  }

  /// Persists [instance] to its JSON file (create or update).
  static Future<bool> _saveToS3<T extends Model>(T instance) async {
    final s3KeyPath = _getS3TableKey<T>();

    // load records from s3

    final allRecords = await _loadS3JsonFileRecords(s3KeyPath);

    if (instance.uuid == null) return false;

    final existingIndex = allRecords.indexWhere((record) => record['uuid'] == instance.uuid);
    final preparedData = _prepareForSave<T>(instance);

    if (existingIndex >= 0) {
      allRecords[existingIndex] = preparedData;
    } else {
      allRecords.add(preparedData);
    }

    return await _s3client.putString(s3KeyPath, jsonEncode(allRecords), contentType: 'application/json', acl: S3Acl.private);
  }

  static Future<List<Map<String, dynamic>>> _loadS3JsonFileRecords(String s3KeyPath) async {
    if (s3KeyPath.isEmpty) {
      return [];
    }
    try {
      final recordsContentString = await _s3client.getString(s3KeyPath);
      if (recordsContentString == null) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(recordsContentString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }


  static Future<bool> migrate<T extends Model>({required T Function(Map<String, dynamic>) constructor}) async {
    final s3KeyPath = _getS3TableKey<T>();

    if (await _s3client.objectExists(s3KeyPath)) {
      _jsonConstructors[T] = constructor;
      return true;
    }

    if (await _s3client.putString(s3KeyPath, jsonEncode({}), contentType: 'application/json', acl: S3Acl.private)) {
      _jsonConstructors[T] = constructor;
      return true;
    }

    return false;


  }


  static Future<List<Map<String, dynamic>>> jsonIndex<T extends Model>() async {
    try {
     return await _loadS3JsonFileRecords(_getS3TableKey<T>());
    } catch (e) {
      return [];
    }
  }

  static Future<List<T>> index<T extends Model>() async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return [];

    try {
      final jsonRecords = await jsonIndex<T>();
      return jsonRecords.map((item) => constructor(item) as T).toList();
    } catch (e, stack) {
      print('Error reading table file: $e\n$stack');
      return [];
    }
  }

  /// Alias for `index<T>()`.
  static Future<List<T>> all<T extends Model>() async => index<T>();

  /// Counts total records.
  static Future<int> count<T extends Model>() async {
    try {
      return await jsonIndex<T>().then((records) => records.length);
    } catch (e) {
      return 0;
    }
  }

  /// Checks if record with [id] (UUID) exists.
  static Future<bool> exists<T extends Model>({required dynamic id}) async {
    try {
      final records = await jsonIndex<T>();
      return records.any((r) => r['uuid'] == id);
    } catch (e) {
      return false;
    }
  }

  /// Finds record by UUID.
  static Future<T?> find<T extends Model>({required String uuid}) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

    try {
      final models = await index<T>();
      return models.firstWhereOrNull((m) => m.uuid == uuid);
    } catch (e) {
      return null;
    }
  }

  /// Finds first record where [field] == [value].
  static Future<T?> findBy<T extends Model>({required String field, required dynamic value}) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

    try {
      final records = await jsonIndex<T>();
      final record = records.firstWhereOrNull((r) => r[field] == value);
      if (record == null) return null;
      return constructor(record) as T;
    } catch (e) {
      return null;
    }
  }

  static Future<T?> findByUUID<T extends Model>(String uuid) async {


    try {
      final constructor = _jsonConstructors[T];
      if (constructor == null) return null;

      final records = await jsonIndex<T>();
      final record = records.firstWhereOrNull((r) => r['uuid'] == uuid);

      if (record == null) return null;

      return constructor(record) as T;

    } catch (e) {
      return null;
    }
  }

  /// Creates a new record from [json].
  static Future<T?> create<T extends Model>(Map<String, dynamic> json) async {
    if (json.isEmpty) return null;
    json
      ..remove('id')
      ..remove('uuid')
      ..remove('created_at')
      ..remove('updated_at');

    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

    try {
      final instance = constructor(json) as T;
      if (!await instance.save(disk: .s3)) return null;
      return instance;
    } catch (e) {
      return null;
    }
  }

  /// Saves [instance] (create if new, update if exists).
  static Future<bool> save<T extends Model>(T instance) async {
    if (instance.uuid == null || instance.createdAt == null) {
      return await _create<T>(instance);
    } else {
      return await _update<T>(instance);
    }
  }

  static Future<bool> update<T extends Model>({required dynamic id, required String field, required dynamic value}) async {


    try {
      final allRecords = await _loadS3JsonFileRecords(_getS3TableKey<T>());
      final index = allRecords.indexWhere((record) => record['uuid'] == id);
      if (index < 0) return false;

      allRecords[index][field] = value;
      allRecords[index]['updated_at'] = DateTime.now().toUtc().toIso8601String();
      return await _s3client.putString(_getS3TableKey<T>(), jsonEncode(allRecords), contentType: 'application/json', acl: S3Acl.private);

    } catch (e) {
      return false;
    }
  }

  /// Deletes record by UUID.
  static Future<bool> delete<T extends Model>({required String uuid}) async {

    try {
      final allRecords = await jsonIndex<T>();
      allRecords.removeWhere((record) => record['uuid'] == uuid);
      return await _s3client.putString(_getS3TableKey<T>(), jsonEncode(allRecords), contentType: 'application/json', acl: S3Acl.private);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> truncate<T extends Model>() async {
    try {
      return await _s3client.putString(_getS3TableKey<T>(), jsonEncode({}), contentType: 'application/json', acl: S3Acl.private);
    } catch (e) {
      return false;
    }


  }

  static Future<List<T>> where<T extends Model>({required String field, String comp = "==", dynamic value}) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return [];

    try {
      final records = await jsonIndex<T>();
      final filtered = records.where((r) {
        final fieldValue = r[field];
        switch (comp) {
          case "==":
            return fieldValue == value;
          case "!=":
            return fieldValue != value;
          case ">":
            return fieldValue is num && fieldValue > value;
          case "<":
            return fieldValue is num && fieldValue < value;
          case ">=":
            return fieldValue is num && fieldValue >= value;
          case "<=":
            return fieldValue is num && fieldValue <= value;
          default:
            return false;
        }
      }).toList();

      return filtered.map((json) => constructor(json) as T).toList();
    } catch (e) {
      return [];
    }
  }

  /// Returns first record matching `where()` condition.
  static Future<T?> firstWhere<T extends Model>({required String field, String comp = "==", dynamic value}) async {
    final constructor = _jsonConstructors[T];
    if (constructor == null) return null;

    try {
      final records = await jsonIndex<T>();
      final record = records.firstWhereOrNull((r) {
        final fieldValue = r[field];
        switch (comp) {
          case "==":
            return fieldValue == value;
          case "!=":
            return fieldValue != value;
          case ">":
            return fieldValue is num && fieldValue > value;
          case "<":
            return fieldValue is num && fieldValue < value;
          case ">=":
            return fieldValue is num && fieldValue >= value;
          case "<=":
            return fieldValue is num && fieldValue <= value;
          default:
            return false;
        }
      });
      if (record == null) return null;
      return constructor(record) as T;
    } catch (e) {
      return null;
    }
  }

  /// Updates instance with partial [withJson].
  static Future<bool> updateInstance<T extends Model>({required T instance, required Map<String, dynamic> withJson}) async {

    final constructor = _jsonConstructors[T];
    if (constructor == null) return false;

    withJson.remove('uuid');
    withJson.remove('id');
    withJson.remove('created_at');

    final currentJson = _prepareForSave<T>(instance);
    currentJson.addAll(withJson);

    final updatedInstance = constructor(currentJson) as T;
    return await save<T>(updatedInstance);
  }

  /// Deletes [instance] by UUID.
  static Future<bool> deleteInstance<T extends Model>({required T instance}) async {
    if (instance.uuid == null) return false;
    return await delete<T>(uuid: instance.uuid!);
  }

  /// Saves [instance].
  static Future<bool> saveInstance<T extends Model>({required T instance}) async {
    return await save<T>(instance);
  }


}
