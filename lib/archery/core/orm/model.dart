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

/// Storage backends for model persistence.
enum DatabaseDisk {
  /// JSON files in `storage/json_file_models/`
  file,

  /// SQLite database -> storage/database.sqlite
  sqlite,
  pgsql,

  /// AWS S3 (planned)
  s3,
}

/// Abstract base class for all data models.
///
/// Provides:
/// - Common fields: `id`, `uuid`, `createdAt`, `updatedAt`
/// - Unified CRUD API across backends
/// - JSON serialization
/// - Disk-agnostic static methods
///
/// **Usage:**
/// ```dart
/// class User extends Model {
///   String name;
///   String email;
///
///   User({this.name, this.email});
///
///   @override
///   Map<String, dynamic> toJson() => {
///     'name': name,
///     'email': email,
///   };
///
///   @override
///   Map<String, dynamic> toMetaJson() => {
///     'id': id,
///     'uuid': uuid,
///     'created_at': createdAt?.toIso8601String(),
///     'updated_at': updatedAt?.toIso8601String(),
///   };
/// }
/// ```
abstract class Model
{
  /// Primary key (auto-incremented by backend).
  int? id;

  /// UUID for cross-backend identification.
  String? uuid;

  /// Creation timestamp (UTC).
  DateTime? createdAt;

  /// Last update timestamp (UTC).
  DateTime? updatedAt;

  /// Default storage backend for all models.
  /// can be overridden per-class
  /// Can be overridden per-operation.
  static const defaultDisk = DatabaseDisk.sqlite;
  DatabaseDisk disk = defaultDisk;

  /// Serializes model data (excluding metadata).
  ///
  /// Override in subclass.
  Map<String, dynamic> toJson();

  /// Serializes metadata fields (`id`, `uuid`, timestamps).
  ///
  /// Used internally by backends.
  Map<String, dynamic> toMetaJson();

  /// Constructs model from JSON.
  ///
  /// Parses `created_at` and `updated_at` safely.
  Model.fromJson(Map<String, dynamic> json) {
    id = json['id'] as int?;

    uuid = json['uuid'] as String?;

    if (json['created_at'] != null) {
      //  try here for DateTime.parse
      try {
        createdAt = DateTime.parse(json['created_at']);
      } catch (e) {
        // Todo - more tests needed here to decide on created_at/updated_at formats
        // Postgres returns a string which doesnt parse to date
        // a string wont have datetime props and methods.
        // considering a get createdAt =>
        // first test seem to be passing... leaving for redundancy
        // key your eye on datetime format behaviors from different dbs
        //datetime might not be able to parse it!
        createdAt = json['created_at'];
      }
    }

    if (json['updated_at'] != null) {
      //  try here for DateTime.parse
      try {
        // updatedAt = json['updated_at'];
        updatedAt = DateTime.parse(json['updated_at']);
      } catch (e) {
        // Todo - more tests needed here to decide on created_at/updated_at formats
        // Postgres returns a string which doesnt parse to date
        updatedAt = json['updated_at'];
      }
    }
  }

  /// Human-readable string representation.
  @override
  String toString() {
    if (id == null) {
      return '$runtimeType-UUID: $uuid';
    } else {
      return '$runtimeType-ID: $id';
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Instance Methods (to be implemented by backends)
  // ──────────────────────────────────────────────────────────────────────

  /// Saves the current instance.
  Future<bool> save({DatabaseDisk disk = Model.defaultDisk});

  /// Deletes the current instance.
  Future<bool> delete({DatabaseDisk disk = Model.defaultDisk});

  /// Updates the current instance with new data.
  Future<bool> update({required Map<String, dynamic> withJson, DatabaseDisk disk = Model.defaultDisk});

  static String _getTableName<T>() {
    final typeName = T.toString();
    final snakeCase = typeName.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (match) => '_');
    return '${snakeCase.toLowerCase()}s';
  }

  String _getInstanceTableName() {
    final typeName = runtimeType.toString();
    final snakeCase = typeName.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (match) => '_');
    return '${snakeCase.toLowerCase()}s';
  }









  // ──────────────────────────────────────────────────────────────────────
  // Static CRUD API (disk-agnostic)
  // ──────────────────────────────────────────────────────────────────────

  /// Saves an [instance] to the specified [disk].
  ///
  /// Returns `true` on success.
  static Future<bool> saveInstance<T extends Model>({required T instance, DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.save<T>(instance);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.save<T>(instance);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.save<T>(instance);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.save<T>(instance);
        } catch (e) {
          return false;
        }
    }
  }

  /// Deletes an [instance] by UUID.
  static Future<bool> deleteInstance<T extends Model>({required T instance, DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.delete<T>(uuid: instance.uuid!);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.delete<T>(instance.id);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.delete<T>(uuid: instance.uuid!);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.delete<T>(id: instance.id!);
        } catch (e) {
          return false;
        }
    }
  }

  /// Updates an [instance] with [withJson] data.
  static Future<bool> updateInstance<T extends Model>({required T instance, required Map<String, dynamic> withJson, DatabaseDisk disk = DatabaseDisk.file}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.updateInstance<T>(instance: instance, withJson: withJson);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.updateInstance<T>(instance: instance, withJson: withJson);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.updateInstance<T>(instance: instance, withJson: withJson);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.updateInstance<T>(instance: instance, withJson: withJson);
        } catch (e) {
          return false;
        }
    }
  }

  /// Returns all instances of type [T].
  ///
  /// Alias for `index<T>()`.
  static Future<List<T>> all<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {
    return index<T>(disk: disk);
  }

  /// Retrieves all instances of type [T].
  static Future<List<T>> index<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.index<T>();
        } catch (e) {
          return [];
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.index<T>();
        } catch (e) {
          return [];
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.index<T>();
        } catch (e) {
          return [];
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.index<T>();
        } catch (e) {
          return [];
        }
    }
  }

  /// Counts total instances of type [T].
  static Future<int> count<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.count<T>();
        } catch (e) {
          return 0;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.count<T>();
        } catch (e) {
          return 0;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.count<T>();
        } catch (e) {
          return 0;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.count<T>();
        } catch (e) {
          return 0;
        }
    }
  }

  /// Checks if a record with [id] exists.
  static Future<bool> exists<T extends Model>({required dynamic id, DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.exists<T>(id: id);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.exists<T>(id: id);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.exists<T>(id: id);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.exists<T>(id: id);
        } catch (e) {
          return false;
        }
    }
  }

  /// Finds a record by [id] (UUID or primary key).
  static Future<T?> find<T extends Model>({required dynamic id, DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.find<T>(uuid: id);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.find<T>(id: id);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.find<T>(uuid: id);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.find<T>(id: id);
        } catch (e) {
          return null;
        }
    }
  }

  static Future<dynamic> findOrFail<T extends Model>({required HttpRequest request, required dynamic id, DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          final model = await JsonFileModel.find<T>(uuid: id);
          if (model != null) {
            model.disk = .file;
            return model;
          }
          return request.notFound();
        } catch (e) {
          return request.notFound();
        }
      case DatabaseDisk.sqlite:
        try {
          final model = await SQLiteModel.find<T>(id: id);
          if (model != null) {
            model.disk = .sqlite;
            return model;
          }
          return request.notFound();
        } catch (e) {
          return request.notFound();
        }
      case DatabaseDisk.s3:
        try {
          final model = await S3JsonFileModel.find<T>(uuid: id);
          if (model != null) {
            model.disk = .s3;
            return model;
          }
          return request.notFound();
        } catch (e) {
          return request.notFound();
        }
      case DatabaseDisk.pgsql:
        try {
          final model = await PostgresModel.find<T>(id: id);
          if (model != null) {
            model.disk = .pgsql;
            return model;
          }
          return request.notFound();
        } catch (e) {
          return request.notFound();
        }
    }
  }

  /// Finds first record where [field] matches [value].
  static Future<T?> findBy<T extends Model>({required String field, required dynamic value, DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.findBy<T>(field: field, value: value);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.findBy<T>(field: field, value: value);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.findBy<T>(field: field, value: value);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.findBy<T>(field: field, value: value);
        } catch (e) {
          return null;
        }
    }
  }

  static Future<T?> findByUUID<T extends Model>({required String uuid, required dynamic value, DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.findByUUID<T>(uuid);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.findByUUID<T>(uuid);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.findByUUID<T>(uuid);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.findByUUID<T>(uuid);
        } catch (e) {
          return null;
        }
    }
  }

  /// Filters records where [field] [comp] [value].
  ///
  /// Supported [comp]: `==`, `!=`, `>`, `<`, `>=`, `<=`, `contains`
  static Future<List<T>> where<T extends Model>({required String field, required dynamic value, String comp = "==", DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          final models = await JsonFileModel.where<T>(field: field, value: value, comp: comp);
          if (models.isNotEmpty) {
            models.map((model) => model.disk = .file);
            return models;
          }
          return [];
        } catch (e) {
          return [];
        }
      case DatabaseDisk.sqlite:
        try {
          final models = await SQLiteModel.where<T>(field: field, value: value, comp: comp);
          if (models.isNotEmpty) {
            models.map((model) => model.disk = .sqlite);
            return models;
          }
          return [];
        } catch (e) {
          return [];
        }
      case DatabaseDisk.s3:
        try {
          final models = await S3JsonFileModel.where<T>(field: field, value: value, comp: comp);
          if (models.isNotEmpty) {
            models.map((model) => model.disk = .s3);
            return models;
          }
          return [];
        } catch (e) {
          return [];
        }
      case DatabaseDisk.pgsql:
        try {
          final models = await PostgresModel.where<T>(field: field, value: value, comp: comp);
          if (models.isNotEmpty) {
            models.map((model) => model.disk = .pgsql);
            return models;
          }
          return [];
        } catch (e) {
          return [];
        }
    }
  }

  /// Returns first record matching `where()` condition.
  static Future<T?> firstWhere<T extends Model>({required String field, required dynamic value, String comp = "==", DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          final model = await JsonFileModel.firstWhere<T>(field: field, value: value, comp: comp);
          if (model != null) {
            model.disk = .file;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
      case DatabaseDisk.sqlite:
        try {
          final model = await SQLiteModel.firstWhere<T>(field: field, value: value, comp: comp);
          if (model != null) {
            model.disk = .sqlite;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
      case DatabaseDisk.s3:
        try {
          final model = await S3JsonFileModel.firstWhere<T>(field: field, value: value, comp: comp);
          if (model != null) {
            model.disk = .s3;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
      case DatabaseDisk.pgsql:
        try {
          final model = await PostgresModel.firstWhere<T>(field: field, value: value, comp: comp);
          if (model != null) {
            model.disk = .pgsql;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
    }
  }

  static Future<dynamic> firstOrFail<T extends Model>({required HttpRequest request, required String field, required dynamic value, String comp = "==", DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          final model = await JsonFileModel.firstWhere<T>(field: field, value: value, comp: comp);
          if (model != null) {
            model.disk = .file;
            return model;
          }
          return request.notFound();
        } catch (e) {
          return request.notFound();
        }
      case DatabaseDisk.sqlite:
        try {
          final model = await SQLiteModel.firstWhere<T>(field: field, value: value, comp: comp);
          if (model != null) {
            model.disk = .sqlite;
            return model;
          }
          return request.notFound();
        } catch (e) {
          return request.notFound();
        }
      case DatabaseDisk.s3:
        try {
          final model = await S3JsonFileModel.firstWhere<T>(field: field, value: value, comp: comp);
          if (model != null) {
            model.disk = .s3;
            return model;
          }
          return request.notFound();
        } catch (e) {
          return request.notFound();
        }
      case DatabaseDisk.pgsql:
        try {
          final model = await PostgresModel.firstWhere<T>(field: field, value: value, comp: comp);
          if (model != null) {
            model.disk = .pgsql;
            return model;
          }
          return request.notFound();
        } catch (e) {
          return request.notFound();
        }
    }
  }

  /// Creates a new record from [fromJson].
  static Future<T?> create<T extends Model>({required Map<String, dynamic> fromJson, DatabaseDisk disk = Model.defaultDisk}) async {
    if (fromJson['password'] != null) {
      fromJson['password'] = Hasher.hashPassword(fromJson['password']);
    }
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.create<T>(fromJson);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.create<T>(fromJson);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.create<T>(fromJson);
        } catch (e) {
          return null;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.create<T>(fromJson);
        } catch (e) {
          return null;
        }
    }
  }

  /// Alias for `saveInstance`.
  static Future<bool> store<T extends Model>({required T instance, DatabaseDisk disk = Model.defaultDisk}) async {
    return await saveInstance<T>(instance: instance, disk: disk);
  }

  /// Updates a single field of a record by [id].
  static Future<bool> patch<T extends Model>({required dynamic id, required String field, required dynamic value, DatabaseDisk disk = DatabaseDisk.file}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.update<T>(id: id, field: field, value: value);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.update<T>(id: id, field: field, value: value);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.update<T>(id: id, field: field, value: value);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.update<T>(id: id, field: field, value: value);
        } catch (e) {
          return false;
        }
    }
  }

  /// Deletes a record by [id].
  static Future<bool> destroy<T extends Model>({required dynamic id, DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.delete<T>(uuid: id);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.delete<T>(id);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.delete<T>(uuid: id);
        } catch (e) {
          return false;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.delete<T>(id: id);
        } catch (e) {
          return false;
        }
    }
  }

  /// Deletes all records of type [T].
  static Future<bool> truncate<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {
    switch (disk) {
      case DatabaseDisk.file:
        try {
          return await JsonFileModel.truncate<T>();
        } catch (e) {
          return false;
        }
      case DatabaseDisk.sqlite:
        try {
          return await SQLiteModel.truncate<T>();
        } catch (e) {
          return false;
        }
      case DatabaseDisk.s3:
        try {
          return await S3JsonFileModel.truncate<T>();
        } catch (e) {
          return false;
        }
      case DatabaseDisk.pgsql:
        try {
          return await PostgresModel.truncate<T>();
        } catch (e) {
          return false;
        }
    }
  }
}


/// Instance-level persistence helpers for [Model] types.
///
/// This mixin forwards instance operations (`save`, `update`, `delete`) to the
/// static Archery ORM functions while respecting the model's configured [disk]
/// (or an explicitly provided disk override).
mixin InstanceDatabaseOps<T extends Model> on Model {
  @override
  Future<bool> save({DatabaseDisk? disk}) async => await Model.saveInstance<T>(instance: this as T, disk: disk ?? this.disk);

  @override
  Future<bool> delete({DatabaseDisk? disk}) async => await Model.deleteInstance<T>(instance: this as T, disk: disk ?? this.disk);

  @override
  Future<bool> update({required Map<String, dynamic> withJson, DatabaseDisk? disk}) async => await Model.updateInstance<T>(instance: this as T, withJson: withJson, disk: disk ?? this.disk);
}

/// Relationship helpers for Archery ORM models.
///
/// Archery infers foreign keys based on the current model’s table name:
/// - File/S3 disks: uses UUID-based keys like `<model>_uuid`
/// - SQLite/Postgres disks: uses integer keys like `<model>_id`
///
/// Example:
/// `Post.hasMany<Comment>()` will query comments using `post_id` (SQL) or
/// `post_uuid` (file/S3), depending on the disk.
extension Relationships on Model {
  Future<T?> hasOne<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {

    try {
      final tableName = _getInstanceTableName();
      final foreignTableSingular = tableName.substring(0, tableName.length - 1);
      final data = toMetaJson();

      switch (disk) {
        case DatabaseDisk.file:
        case DatabaseDisk.s3:
          final foreignUuidKey = "${foreignTableSingular}_uuid";
          return Model.firstWhere<T>(field: foreignUuidKey, value: data['uuid'], disk: disk);

        case DatabaseDisk.sqlite:
        case DatabaseDisk.pgsql:
          final foreignIdKey = "${foreignTableSingular}_id";
          return Model.firstWhere<T>(field: foreignIdKey, value: data['id'], disk: disk);
      }

    }catch(e) {
      return null;
    }

  }

  Future<List<T>> hasMany<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {

    try {
      final tableName = _getInstanceTableName();
      final foreignTableSingular = tableName.substring(0, tableName.length - 1);
      final data = toMetaJson();

      switch (disk) {
        case DatabaseDisk.file:
        case DatabaseDisk.s3:
          final foreignUuidKey = "${foreignTableSingular}_uuid";
          return Model.where<T>(field: foreignUuidKey, value: data['uuid'], disk: disk);

        case DatabaseDisk.sqlite:
        case DatabaseDisk.pgsql:
          final foreignIdKey = "${foreignTableSingular}_id";
          return Model.where<T>(field: foreignIdKey, value: data['id'], disk: disk);
      }

    }catch(e) {
      return [];
    }

  }

  Future<T?> belongsTo<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {
    try {
      final tableName = Model._getTableName<T>();
      final foreignTableSingular = tableName.substring(0, tableName.length - 1);
      final data = toMetaJson();

      switch (disk) {
        case DatabaseDisk.file:
        case DatabaseDisk.s3:
          final foreignUuidKey = "${foreignTableSingular}_uuid";
          final val = data[foreignUuidKey];
          if (val == null) return null;
          return Model.firstWhere<T>(field: "uuid", value: val, disk: disk);

        case DatabaseDisk.sqlite:
        case DatabaseDisk.pgsql:
          final foreignIdKey = "${foreignTableSingular}_id";
          final val = data[foreignIdKey];
          if (val == null) return null;
          return Model.firstWhere<T>(field: "id", value: val, disk: disk);
      }

    }catch(e) {
      return null;
    }

  }


}
