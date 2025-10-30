import 'package:archery/archery/archery.dart';

final class User extends Model {
  late String name;
  late String email;
  String? password;


  User({required this.name, required this.email, String? password} ) :  password = password != null ? Hasher.hashPassword(password) : null, super.fromJson({});

  User.fromJson(Map<String, dynamic> json) : super.fromJson(json) {

    if(json['name'] != null && json['name'] is String) {
      name = json['name'];
    }

    if(json['email'] != null && json['email'] is String) {
      email = json['email'];
    }

    if(json['password'] != null && json['password'] is String && json['password'].toString().isNotEmpty) {
      password = json['password'];
    }
  }

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


  static Map<String, String> columnDefinitions = {'name': 'TEXT NOT NULL', 'email': 'TEXT NOT NULL UNIQUE', 'password': 'TEXT'};

  @override
  Future<bool> save({Disk disk = Disk.file}) async => await Model.saveInstance<User>(instance: this, disk: disk);
  @override
  Future<bool> delete({Disk disk = Disk.file}) async => await Model.deleteInstance<User>(instance: this, disk: disk);
  @override
  Future<bool> update({Disk disk = Disk.file}) async => await Model.updateInstance<User>(instance: this, withJson: toMetaJson(), disk: disk);



}

