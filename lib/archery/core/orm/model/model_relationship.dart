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

/// Supported relationship types for model-to-model associations.
///
/// These values are used by relationship helpers and mutation helpers to
/// describe how two models should be resolved or linked.
///
/// Example:
/// ```dart
/// final type = ModelRelationshipType.hasMany;
/// ```
enum ModelRelationshipType {
  /// A one-to-one relationship where the related model stores the foreign key.
  hasOne,

  /// A one-to-many relationship where related models store the foreign key.
  hasMany,

  /// An inverse one-to-one or many-to-one relationship where this model stores
  /// the foreign key.
  belongsToOne,

  /// A many-to-many relationship resolved through a pivot table.
  belongsToMany
}

/// Relationship resolution helpers attached to [Model].
///
/// These helpers resolve related models using conventional foreign-key naming
/// derived from model table names.
///
/// Foreign key behavior depends on the selected [DatabaseDisk]:
/// - `file` and `s3` use `<model>_uuid` keys
/// - `sqlite` and `pgsql` use `<model>_id` keys
///
/// Example:
/// ```dart
/// final profile = await user.hasOne<Profile>();
/// final posts = await user.hasMany<Post>();
/// ```
extension ModelRelationships on Model {

  /// Resolves a one-to-one related model.
  ///
  /// The related model is looked up using the current model's identifier and
  /// conventional foreign-key naming for the selected [disk].
  ///
  /// Returns the related model when found, otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// final profile = await user.hasOne<Profile>();
  /// if (profile != null) {
  ///   print(profile.toJson());
  /// }
  /// ```
  Future<T?> hasOne<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {
    try {
      final foreignTableSingular = getInstanceTableSingularName();
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
    } catch (e,stack) {
      App().archeryLogger.error("Error resolving hasOne", {"origin": "ext ModelRelationships hasOne", "error": e.toString(), "stack": stack.toString()});
      return null;
    }
  }

  /// Resolves all one-to-many related models.
  ///
  /// Related models are queried using the current model's identifier and
  /// conventional foreign-key naming for the selected [disk].
  ///
  /// Returns an empty list when no related models are found or resolution
  /// fails.
  ///
  /// Example:
  /// ```dart
  /// final comments = await post.hasMany<Comment>();
  /// print(comments.length);
  /// ```
  Future<List<T>> hasMany<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {
    try {
      final foreignTableSingular = getInstanceTableSingularName();
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
    } catch (e, stack) {
      App().archeryLogger.error("Error resolving hasMany", {"origin": "ext ModelRelationships hasMany", "error": e.toString(), "stack": stack.toString()});
      return [];
    }
  }

  /// Resolves the parent model for an inverse relationship.
  ///
  /// This method reads the foreign key stored on the current model, then loads
  /// the related parent model by `uuid` or `id` depending on [disk].
  ///
  /// Returns the parent model when found, otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// final author = await post.belongsToOne<User>();
  /// if (author != null) {
  ///   print(author.email);
  /// }
  /// ```
  Future<T?> belongsToOne<T extends Model>({DatabaseDisk disk = Model.defaultDisk}) async {
    try {
      final foreignTableSingular = Model.getTableSingularName<T>();
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
    } catch (e, stack) {
      App().archeryLogger.error("Error resolving belongsToOne", {"origin": "ext ModelRelationships belongsToOne", "error": e.toString(), "stack": stack.toString()});
      return null;
    }
  }

  /// Resolves many-to-many related models through a pivot table.
  ///
  /// For SQLite, this method queries the pivot table, extracts sibling IDs, and
  /// then loads all matching models with `Model.whereIn`.
  ///
  /// Currently, pivot-table resolution is implemented for `sqlite` only.
  ///
  /// Parameters:
  /// - `table`: The pivot table definition used to join the two models.
  /// - `disk`: The storage backend. Defaults to [Model.defaultDisk].
  ///
  /// Returns an empty list when no related models are found or resolution
  /// fails.
  ///
  /// Example:
  /// ```dart
  /// final roles = await user.belongsToMany<Role>(
  ///   table: userRolesPivot,
  ///   disk: DatabaseDisk.sqlite,
  /// );
  /// ```
  Future<List<T>> belongsToMany<T extends Model>({required PivotTable table, DatabaseDisk disk = Model.defaultDisk}) async {

    try {

      final pivotTableName = table.name;

      final childPrefix = getInstanceTableSingularName();
      final siblingPrefix = Model.getTableSingularName<T>();

      switch (disk) {
        case DatabaseDisk.sqlite:
          final constructor = SQLiteModel.migrations[T];
          if (constructor == null) return [];


          // e.g user_role pivot table
          final childField = "${childPrefix}_id";
          final siblingField = "${siblingPrefix}_id";

          //
          final pivotRecords = await SQLiteModel.database.query(pivotTableName, where: '$childField = ?', whereArgs: [id]);
          if (pivotRecords.isEmpty) return [];

          final siblingIDs = pivotRecords.map((record) => record[siblingField]).toList();
          if (siblingIDs.isEmpty) return [];

          return await Model.whereIn<T>(column: 'id', values: siblingIDs);


        case DatabaseDisk.file:
        // TODO: Handle case.
          throw UnimplementedError();
        case DatabaseDisk.pgsql:
        // TODO: Handle case.
          throw UnimplementedError();
        case DatabaseDisk.s3:
        // TODO: Handle case.
          throw UnimplementedError();
      }

    } catch(e, stack) {
      App().archeryLogger.error("Error resolving belongsToMany", {"origin": "ext ModelRelationships belongsToMany", "error": e.toString(), "stack": stack.toString()});
      return [];

    }




  }

}

/// Relationship mutation and eager-loading helpers attached to [Model].
///
/// These helpers support attaching and detaching related models and building
/// loaded JSON payloads that include relationship data.
///
/// Example:
/// ```dart
/// await user.attach(
///   role,
///   relationship: ModelRelationshipType.belongsToMany,
///   table: userRolesPivot,
/// );
/// ```
extension ModelRelationshipOps on Model {
  /// Attaches [sibling] to this model using the given [relationship] type.
  ///
  /// Behavior depends on the relationship:
  /// - `hasOne` / `hasMany`: writes this model's foreign key onto [sibling]
  /// - `belongsToOne`: writes the sibling foreign key onto this model
  /// - `belongsToMany`: inserts a pivot-table record
  ///
  /// For `belongsToMany`, [table] is required.
  ///
  /// Returns `true` when the relationship is successfully attached; otherwise
  /// returns `false`.
  ///
  /// Example:
  /// ```dart
  /// await user.attach(
  ///   profile,
  ///   relationship: ModelRelationshipType.hasOne,
  /// );
  ///
  /// await user.attach(
  ///   role,
  ///   relationship: ModelRelationshipType.belongsToMany,
  ///   table: UserRolePivotTable,
  ///   disk: DatabaseDisk.sqlite,
  /// );
  /// ```
  Future<bool> attach(Model sibling, {required ModelRelationshipType relationship, PivotTable? table, DatabaseDisk disk = Model.defaultDisk,}) async {
    try {

      final childPrefix = getInstanceTableSingularName();
      final siblingPrefix = sibling.getInstanceTableSingularName();

      switch (relationship) {

        case .hasOne:
        case .hasMany:

          switch (disk) {
            case .sqlite:
            case .pgsql:
              final childField = "${childPrefix}_id";
              return await sibling.update(withJson: {childField: id});

            case .file:
            case .s3:
              final childField = "${childPrefix}_uuid";
              return await sibling.update(withJson: {childField: uuid});
          }

        case .belongsToOne:
          switch (disk) {
            case .sqlite:
            case .pgsql:
              final siblingField = "${siblingPrefix}_id";
              return  update(withJson: {siblingField: sibling.id});

            case .file:
            case .s3:
              final siblingField = "${siblingPrefix}_uuid";
              return await update(withJson: {siblingField: sibling.uuid});
          }

        case .belongsToMany:

          if(table == null) {
            return false;
          }

          switch(disk) {
            case .sqlite:

              final sqliteDB = App().container.make<SQLiteDatabase>();
              final tableName = table.name;

              final childPrefix = getInstanceTableSingularName();
              final childField = "${childPrefix}_id";

              final siblingPrefix = sibling.getInstanceTableSingularName();
              final siblingField = "${siblingPrefix}_id";

              final createdAt = DateTime.now().toIso8601String();
              final updatedAt = DateTime.now().toIso8601String();

              await sqliteDB.rawInsert(
                  'INSERT INTO $tableName ($childField, $siblingField, created_at, updated_at) VALUES(?, ?, ?, ?)',
                  [id, sibling.id, createdAt, updatedAt]
              );

              return true;

          // todo : pivot tables currently implemented for sqlite.
            case DatabaseDisk.file:
              throw UnimplementedError();
            case DatabaseDisk.pgsql:
              throw UnimplementedError();
            case DatabaseDisk.s3:
              throw UnimplementedError();
          }
      }
    } catch(e,stack) {
      App().archeryLogger.error("Error attaching sibling", {"origin": "ext ModelRelationshipOps attach", "error": e.toString(), "stack": stack.toString()});
      return false;
    }
  }

  /// Detaches [sibling] from this model using the given [relationship] type.
  ///
  /// Behavior depends on the relationship:
  /// - `hasOne` / `hasMany`: clears this model's foreign key from [sibling]
  /// - `belongsToOne`: clears the sibling foreign key from this model
  /// - `belongsToMany`: removes the pivot-table record
  ///
  /// For `belongsToMany`, [table] is required.
  ///
  /// Returns `true` when the relationship is successfully detached; otherwise
  /// returns `false`.
  ///
  /// Example:
  /// ```dart
  /// await user.detach(
  ///   profile,
  ///   relationship: ModelRelationshipType.hasOne,
  /// );
  ///
  /// await user.detach(
  ///   role,
  ///   relationship: ModelRelationshipType.belongsToMany,
  ///   table: userRolesPivot,
  ///   disk: DatabaseDisk.sqlite,
  /// );
  /// ```
  Future<bool> detach(Model sibling, {required ModelRelationshipType relationship, PivotTable? table, DatabaseDisk disk = Model.defaultDisk,}) async {

    try {

      final childPrefix = getInstanceTableSingularName();
      final siblingPrefix = sibling.getInstanceTableSingularName();

      switch (relationship) {

        case .hasOne:
        case .hasMany:

          switch (disk) {
            case .sqlite:
            case .pgsql:
              final childField = "${childPrefix}_id";
              return await sibling.update(withJson: {childField: null});

            case .file:
            case .s3:
              final childField = "${childPrefix}_uuid";
              return await sibling.update(withJson: {childField: null});
          }

        case .belongsToOne:

          switch (disk) {
            case .sqlite:
            case .pgsql:
              final siblingField = "${siblingPrefix}_id";
              return  update(withJson: {siblingField: null});

            case .file:
            case .s3:
              final siblingField = "${siblingPrefix}_uuid";
              return await update(withJson: {siblingField: null});
          }

        case .belongsToMany:

          if(table == null) {
            return false;
          }

          switch(disk) {
            case .sqlite:

              final sqliteDB = App().container.make<SQLiteDatabase>();

              final childPrefix = getInstanceTableSingularName();
              final childField = "${childPrefix}_id";

              final siblingPrefix = sibling.getInstanceTableSingularName();
              final siblingField = "${siblingPrefix}_id";

              await sqliteDB.delete(
                table.name,
                where: '$childField = ? AND $siblingField = ?',
                whereArgs: [id, sibling.id],
              );

              return true;

          // todo : pivot tables currently implemented for sqlite.
            case DatabaseDisk.file:
              throw UnimplementedError();
            case DatabaseDisk.pgsql:
              throw UnimplementedError();
            case DatabaseDisk.s3:
              throw UnimplementedError();
          }
      }

    } catch (e, stack) {
      App().archeryLogger.error("Error detaching sibling", {
        "origin": "ext ModelRelationshipOps detach()",
        "error": e.toString(),
        "stack": stack.toString()
      });

      return false;
    }

  }

  /// Loads a relationship and returns this model serialized with the related
  /// data embedded.
  ///
  /// The returned map contains `toJson()` for the current model plus an
  /// additional key for the requested relationship:
  /// - singular table name for `hasOne` and `belongsToOne`
  /// - plural table name for `hasMany` and `belongsToMany`
  ///
  /// For `belongsToMany`, [table] is required.
  ///
  /// Example:
  /// ```dart
  /// final userWithProfile = await user.load<Profile>(
  ///   ModelRelationshipType.hasOne,
  /// );
  ///
  /// final userWithRoles = await user.load<Role>(
  ///   ModelRelationshipType.belongsToMany,
  ///   table: userRolesPivot,
  /// );
  /// ```
  Future<Map<String, dynamic>> load<T extends Model>(ModelRelationshipType relationship, {PivotTable? table}) async {
    switch(relationship) {

      case ModelRelationshipType.hasOne:
        final sibling = await  hasOne<T>();
        final siblingTable = Model.getTableSingularName<T>();
        return {...toJson(), siblingTable : sibling?.toJson()};

      case ModelRelationshipType.hasMany:
        final siblings = await  hasMany<T>();
        final siblingsTable = Model.getTableName<T>();
        return {...toJson(), siblingsTable : siblings.map((sibling) => sibling.toJson()).toList() };
      case ModelRelationshipType.belongsToOne:
        final sibling = await  belongsToOne<T>();
        final siblingTable = Model.getTableSingularName<T>();
        return {...toJson(), siblingTable : sibling?.toJson()};

      case ModelRelationshipType.belongsToMany:
        if(table == null) {
          throw Exception("pivot table is required for belongsToMany relationships");
        }
        final siblings = await  belongsToMany<T>(table: table );
        final siblingsTable = Model.getTableName<T>();
        return {...toJson(), siblingsTable : siblings.map((sibling) => sibling.toJson()).toList() };
    }

  }

}













