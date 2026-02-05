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
enum Disk {
  /// JSON files in `storage/json_file_models/`
  file,

  /// SQLite database -> storage/database.sqlite
  sqlite,

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
abstract class Model {
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
  static const defaultDisk = Disk.sqlite;
  Disk disk = defaultDisk;

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
      try {
        createdAt = DateTime.parse(json['created_at'] as String);
      } catch (e) {
        createdAt = null;
      }
    }

    if (json['updated_at'] != null) {
      try {
        updatedAt = DateTime.parse(json['updated_at'] as String);
      } catch (e) {
        updatedAt = null;
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
  Future<bool> save({Disk disk = Model.defaultDisk});

  /// Deletes the current instance.
  Future<bool> delete({Disk disk = Model.defaultDisk});

  /// Updates the current instance with new data.
  Future<bool> update({Disk disk = Model.defaultDisk});

  // ──────────────────────────────────────────────────────────────────────
  // Static CRUD API (disk-agnostic)
  // ──────────────────────────────────────────────────────────────────────

  /// Saves an [instance] to the specified [disk].
  ///
  /// Returns `true` on success.
  static Future<bool> saveInstance<T extends Model>({required T instance, Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
        try {
          return await JsonFileModel.save<T>(instance);
        } catch (e) {
          return false;
        }
      case Disk.sqlite:
        try {
          return await SQLiteModel.save<T>(instance);
        } catch (e) {
          return false;
        }
      case Disk.s3:
        return false; // Not implemented
    }
  }

  /// Deletes an [instance] by UUID.
  static Future<bool> deleteInstance<T extends Model>({required T instance, Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
        try {
          return await JsonFileModel.delete<T>(uuid: instance.uuid!);
        } catch (e) {
          return false;
        }
      case Disk.sqlite:
        try {
          return await SQLiteModel.delete<T>(instance.id);
        } catch (e) {
          return false;
        }
      case Disk.s3:
        return false;
    }
  }

  /// Updates an [instance] with [withJson] data.
  static Future<bool> updateInstance<T extends Model>({required T instance, required Map<String, dynamic> withJson, Disk disk = Disk.file}) async {
    switch (disk) {
      case Disk.file:
        try {
          return await JsonFileModel.updateInstance<T>(instance: instance, withJson: withJson);
        } catch (e) {
          return false;
        }
      case Disk.sqlite:
        try {
          return await SQLiteModel.updateInstance<T>(instance: instance, withJson: withJson);
        } catch (e) {
          return false;
        }
      case Disk.s3:
        return false;
    }
  }

  /// Returns all instances of type [T].
  ///
  /// Alias for `index<T>()`.
  static Future<List<T>> all<T extends Model>({Disk disk = Model.defaultDisk}) async {
    return index<T>(disk: disk);
  }

  /// Retrieves all instances of type [T].
  static Future<List<T>> index<T extends Model>({Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
        try {
          final models = await JsonFileModel.index<T>();
          if (models.isNotEmpty) {
            models.map((model) => model.disk = .file);
            return models;
          }
          return [];
        } catch (e) {
          return [];
        }
      case Disk.sqlite:
        try {
          final models = await SQLiteModel.index<T>();
          if (models.isNotEmpty) {
            models.map((model) => model.disk = .sqlite);
            return models;
          }
          return [];
        } catch (e) {
          return [];
        }
      case Disk.s3:
        return [];
    }
  }

  /// Counts total instances of type [T].
  static Future<int> count<T extends Model>({Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
        try {
          return await JsonFileModel.count<T>();
        } catch (e) {
          return 0;
        }
      case Disk.sqlite:
        try {
          return await SQLiteModel.count<T>();
        } catch (e) {
          return 0;
        }
      case Disk.s3:
        return 0;
    }
  }

  /// Checks if a record with [id] exists.
  static Future<bool> exists<T extends Model>({required dynamic id, Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
        try {
          return await JsonFileModel.exists<T>(id: id);
        } catch (e) {
          return false;
        }
      case Disk.sqlite:
        try {
          return await SQLiteModel.exists<T>(id: id);
        } catch (e) {
          return false;
        }
      case Disk.s3:
        return false;
    }
  }

  /// Finds a record by [id] (UUID or primary key).
  static Future<T?> find<T extends Model>({required dynamic id, Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
        try {
          final model = await JsonFileModel.find<T>(uuid: id);
          if (model != null) {
            model.disk = .file;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
      case Disk.sqlite:
        try {
          final model = await SQLiteModel.find<T>(id: id);
          if (model != null) {
            model.disk = .sqlite;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
      case Disk.s3:
        return null;
    }
  }

  /// Finds first record where [field] matches [value].
  static Future<T?> findBy<T extends Model>({required String field, required dynamic value, Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
        try {
          final model = await JsonFileModel.findBy<T>(field: field, value: value);
          if (model != null) {
            model.disk = .file;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
      case Disk.sqlite:
        try {
          final model = await SQLiteModel.findBy<T>(field: field, value: value);
          if (model != null) {
            model.disk = .sqlite;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
      case Disk.s3:
        return null;
    }
  }

  /// Filters records where [field] [comp] [value].
  ///
  /// Supported [comp]: `==`, `!=`, `>`, `<`, `>=`, `<=`, `contains`
  static Future<List<T>> where<T extends Model>({required String field, required dynamic value, String comp = "==", Disk disk = Disk.file}) async {
    switch (disk) {
      case Disk.file:
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
      case Disk.sqlite:
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
      case Disk.s3:
        return [];
    }
  }

  /// Returns first record matching `where()` condition.
  static Future<T?> firstWhere<T extends Model>({required String field, required dynamic value, String comp = "==", Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
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
      case Disk.sqlite:
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
      case Disk.s3:
        return null;
    }
  }

  /// Creates a new record from [fromJson].
  static Future<T?> create<T extends Model>({required Map<String, dynamic> fromJson, Disk disk = Model.defaultDisk}) async {
    if (fromJson['password'] != null) {
      fromJson['password'] = Hasher.hashPassword(fromJson['password']);
    }
    switch (disk) {
      case Disk.file:
        try {
          final model = await JsonFileModel.create<T>(fromJson);
          if (model != null) {
            model.disk = .file;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
      case Disk.sqlite:
        try {
          final model = await SQLiteModel.create<T>(fromJson);
          if (model != null) {
            model.disk = .file;
            return model;
          }
          return null;
        } catch (e) {
          return null;
        }
      case Disk.s3:
        return null;
    }
  }

  /// Alias for `saveInstance`.
  static Future<bool> store<T extends Model>({required T instance, Disk disk = Model.defaultDisk}) async {
    return await saveInstance<T>(instance: instance, disk: disk);
  }

  /// Updates a single field of a record by [id].
  static Future<bool> patch<T extends Model>({required dynamic id, required String field, required dynamic value, Disk disk = Disk.file}) async {
    switch (disk) {
      case Disk.file:
        try {
          return await JsonFileModel.update<T>(id: id, field: field, value: value);
        } catch (e) {
          return false;
        }
      case Disk.sqlite:
        try {
          return await SQLiteModel.update<T>(id: id, field: field, value: value);
        } catch (e) {
          return false;
        }
      case Disk.s3:
        return false;
    }
  }

  /// Deletes a record by [id].
  static Future<bool> destroy<T extends Model>({required dynamic id, Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
        try {
          return await JsonFileModel.delete<T>(uuid: id);
        } catch (e) {
          return false;
        }
      case Disk.sqlite:
        try {
          return await SQLiteModel.delete<T>(id);
        } catch (e) {
          return false;
        }
      case Disk.s3:
        return false;
    }
  }

  /// Deletes all records of type [T].
  static Future<bool> truncate<T extends Model>({Disk disk = Model.defaultDisk}) async {
    switch (disk) {
      case Disk.file:
        try {
          return await JsonFileModel.truncate<T>();
        } catch (e) {
          return false;
        }
      case Disk.sqlite:
        try {
          return await SQLiteModel.truncate<T>();
        } catch (e) {
          return false;
        }
      case Disk.s3:
        return false;
    }
  }
}
