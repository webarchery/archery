import 'package:archery/archery/archery.dart';

abstract class ModelCrudController<T extends Model> {

  Future<dynamic> index(HttpRequest request);
  Future<dynamic> show(HttpRequest request);

  Future<dynamic> create(HttpRequest request);
  Future<dynamic> store(HttpRequest request);

  Future<dynamic> edit(HttpRequest request);
  Future<dynamic> update(HttpRequest request);

  Future<dynamic> destroy(HttpRequest request);

}