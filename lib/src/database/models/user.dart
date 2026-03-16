import 'package:archery/archery/archery.dart';
/// Core application user model.
///
/// A `User` represents an authenticated or auth-capable account within the
/// framework. It stores identity fields, an optional hashed password, and
/// exposes convenience helpers for loading attached roles.
///
/// Example:
/// ```dart
/// final user = User(
///   name: 'Jane Doe',
///   email: 'jane@example.com',
///   password: 'secret123',
/// );
///
/// print(user.email); // jane@example.com
/// ```
final class User extends Model with InstanceDatabaseOps<User> {
  /// User display name.
  late String name;

  /// User email address.
  late String email;

  /// Hashed password value, when present.
  ///
  /// Passwords passed into the primary constructor are hashed automatically.
  String? password;

  /// Resolves all roles attached to this user through the user/role pivot
  /// table.
  ///
  /// Example:
  /// ```dart
  /// final roles = await user.roles;
  /// print(roles.length);
  /// ```
  Future<List<Role>> get roles async {
    return belongsToMany<Role>(table: UserRolePivotTable());
  }

  /// Creates a new user instance.
  ///
  /// When [password] is provided, it is hashed before being stored on the
  /// model.
  ///
  /// Example:
  /// ```dart
  /// final user = User(
  ///   name: 'Jane Doe',
  ///   email: 'jane@example.com',
  ///   password: 'secret123',
  /// );
  /// ```
  User({required this.name, required this.email, String? password})
    : password = password != null ? Hasher.make(key: password) : null,
      super.fromJson({});

  /// Creates a user model from a JSON map.
  ///
  /// Expected keys:
  /// - `name`
  /// - `email`
  /// - `password`
  ///
  /// Values are assigned only when present and of the expected type.
  ///
  /// Example:
  /// ```dart
  /// final user = User.fromJson({
  ///   'name': 'Jane Doe',
  ///   'email': 'jane@example.com',
  ///   'password': r'$2b$12$...',
  /// });
  /// ```
  User.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    if (json['name'] != null && json['name'] is String) {
      name = json['name'];
    }

    if (json['email'] != null && json['email'] is String) {
      email = json['email'];
    }

    if (json['password'] != null && json['password'] is String && json['password'].toString().isNotEmpty) {
      password = json['password'];
    }
  }

  /// Serializes the user into its standard JSON representation.
  ///
  /// This form excludes the password field and is appropriate for typical
  /// response payloads.
  ///
  /// Example:
  /// ```dart
  /// final json = user.toJson();
  /// print(json['name']);
  /// print(json['email']);
  /// ```
  @override
  Map<String, dynamic> toJson() {
    return {
      "uuid": uuid,
      'name': name,
      'email': email,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }



  /// Returns this user serialized with resolved role data.
  ///
  /// The returned map contains the standard user JSON plus a `roles` key.
  ///
  /// Example:
  /// ```dart
  /// final payload = await user.withRoles();
  /// print(payload['roles']);
  /// ```
  Future<Map<String, dynamic>> withRoles() async {
    return {
      ...toJson(),
      'roles': await roles
    };
  }


  /// Serializes the user into a metadata-oriented JSON map.
  ///
  /// This representation includes internal identifiers and the password field.
  ///
  /// Example:
  /// ```dart
  /// final meta = user.toMetaJson();
  /// print(meta['id']);
  /// print(meta['uuid']);
  /// ```
  @override
  Map<String, dynamic> toMetaJson() {
    return {
      "id": id,
      "uuid": uuid,
      'name': name,
      'email': email,
      "password": password,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Database column definitions for persisted users.
  ///
  /// Example:
  /// ```dart
  /// print(User.columnDefinitions['email']); // TEXT NOT NULL UNIQUE
  /// ```
  static Map<String, String> columnDefinitions = {
    'name': 'TEXT NOT NULL',
    'email': 'TEXT NOT NULL UNIQUE',
    'password': 'TEXT',
  };
}




