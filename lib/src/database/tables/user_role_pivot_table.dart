import 'package:archery/archery/archery.dart';

/// Pivot table linking [User] and [Role] models.
///
/// `UserRolePivotTable` defines the intermediate SQLite pivot schema used for
/// many-to-many user/role relationships.
///
/// This type stores the related `user_id` and `role_id` values and inherits
/// common pivot metadata such as `id`, `createdAt`, and `updatedAt`.
///
/// Example:
/// ```dart
/// final pivot = UserRolePivotTable()
///   ..userID = 1
///   ..roleID = 2;
///
/// print(pivot.name); // user_role
/// ```
class UserRolePivotTable extends PivotTable<User, Role> {

  /// Foreign key pointing to the related [User].
  ///
  /// Example:
  /// ```dart
  /// pivot.userID = 1;
  /// ```
  late final dynamic userID;

  /// Foreign key pointing to the related [Role].
  ///
  /// Example:
  /// ```dart
  /// pivot.roleID = 2;
  /// ```
  late final dynamic roleID;

  /// Serializes the pivot record into a JSON-compatible map.
  ///
  /// Includes the related user/role identifiers and timestamp metadata.
  ///
  /// Example:
  /// ```dart
  /// final json = pivot.toJson();
  /// print(json['user_id']);
  /// print(json['role_id']);
  /// ```
  @override
  Map<String, dynamic> toJson() {
    return {
      "user_id" : userID,
      "role_id" : roleID,
      "createdAt": createdAt?.toIso8601String(),
      "updatedAt": updatedAt?.toIso8601String()
    };
  }

  /// Serializes the pivot record into a metadata-oriented JSON map.
  ///
  /// Includes the database `id` in addition to the relationship fields and
  /// timestamp metadata.
  ///
  /// Example:
  /// ```dart
  /// final meta = pivot.toMetaJson();
  /// print(meta['id']);
  /// ```
  @override
  Map<String, dynamic> toMetaJson() {
    return {
      "id": id,
      "user_id" : userID,
      "role_id" : roleID,
      "createdAt": createdAt?.toIso8601String(),
      "updatedAt": updatedAt?.toIso8601String()
    };
  }

  /// Column definitions for the user/role pivot table.
  ///
  /// The pivot stores two required integer foreign keys:
  /// - `user_id`
  /// - `role_id`
  ///
  /// Example:
  /// ```dart
  /// final columns = pivot.columnDefinitions;
  /// print(columns['user_id']); // INTEGER NOT NULL
  /// print(columns['role_id']); // INTEGER NOT NULL
  /// ```
  @override
   Map<String, String> get columnDefinitions => {
    'user_id': 'INTEGER NOT NULL',
    'role_id': 'INTEGER NOT NULL',
  };
}