import 'package:archery/archery/archery.dart';

/// Provider that seeds default roles, and optionally default users, during
/// application boot.
///
/// This provider delegates to the internal [_RolesSeeder] and is typically used
/// in development or bootstrap flows where role records should exist before the
/// app begins serving requests.
///
/// Example:
/// ```dart
/// final provider = RolesTableSeederProvider();
/// await provider.boot(App().container);
/// ```
class RolesTableSeederProvider  extends Provider {
  /// Boots the provider and runs the role seeder.
  ///
  /// The current boot behavior truncates existing role data and also creates
  /// default users for each built-in role.
  ///
  /// Example:
  /// ```dart
  /// await RolesTableSeederProvider().boot(container);
  /// ```
  @override
  Future<void> boot(ServiceContainer container) async {
    await _RolesSeeder.run(truncate: true, createUsers: true,);
  }
}

/// Internal seeder for default role and user records.
///
/// `_RolesSeeder` creates one record for each [RoleType]. It can also truncate
/// existing role data and optionally create one default user per role.
///
/// Current default seeded users:
/// - `Admin <admin@app.dev>`
/// - `Owner <owner@app.dev>`
/// - `Staff <staff@app.dev>`
/// - `Guest <guest@app.dev>`
///
/// Example:
/// ```dart
/// final ok = await _RolesSeeder.run(
///   truncate: true,
///   createUsers: true,
/// );
/// ```
class _RolesSeeder {
  /// Seeds built-in roles and, optionally, default users.
  ///
  /// Behavior:
  /// - truncates the `Role` table when [truncate] is `true`
  /// - clears the `user_role` pivot table when [truncate] is `true`
  /// - truncates the `User` table when both [truncate] and [createUsers] are
  ///   `true`
  /// - creates one [Role] record for each [RoleType]
  /// - optionally creates one default [User] per role and attaches that role
  ///
  /// Returns `true` when seeding completes successfully, otherwise `false`.
  ///
  /// Example:
  /// ```dart
  /// final ok = await _RolesSeeder.run(
  ///   truncate: true,
  ///   createUsers: true,
  /// );
  ///
  /// print(ok);
  /// ```
  static Future<bool> run({bool truncate = false, bool createUsers = false}) async {

    try {

      if (truncate) {
        await Model.truncate<Role>();
        await SQLiteModel.database.delete('user_role');
      }

      if(truncate && createUsers) {
        await Model.truncate<User>();
      }


      for (final role in RoleType.values) {
        // todo - implement bulk create for models
        final roleModel = await Model.create<Role>(fromJson: {'name': role.name, 'description': role.description});

        if(createUsers) {
          final user = User(name: role.name.capitalize(), email: "${role.name}@app.dev", password: "password");
          await user.save();
          if(! await user.hasRole(role)) {
            await user.attach(roleModel!, relationship: .belongsToMany, table: UserRolePivotTable());
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}