import "package:archery/archery/archery.dart";


/// The quintessential resourceful controller
///
/// How to
///
/// Example:
/// ```dart
///
/// class UsersCrudController implements CrudController {
///
/// @override
/// Future<dynamic> create(HttpRequest request) async {}
///
/// -- insert other crud methods --
///
/// }
///
/// final router = Router();
///
/// router.crud<User>(prefix: "", controller: UsersCrudController());
///
/// can be called without passing the User type hint.
/// router.crud(prefix: "", controller: SomeCrudController());
///
///
/// ```
abstract class CrudController<T extends Model> {

  Future<dynamic> index(HttpRequest request) async {}
  Future<dynamic> show(HttpRequest request) async {}

  Future<dynamic> create(HttpRequest request) async {}
  Future<dynamic> store(HttpRequest request) async {}

  Future<dynamic> edit(HttpRequest request) async {}
  Future<dynamic> update(HttpRequest request) async {}

  Future<dynamic> destroy(HttpRequest request) async {}

}