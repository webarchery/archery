import 'package:archery/archery/archery.dart';

class UserRolePivotTableProvider extends Provider {
 @override
  Future<void> boot(ServiceContainer container) async {
   // default disk is sqlite
   // await UserRolePivotTable().migrate(disk: .sqlite);
   await UserRolePivotTable().migrate();
  }
}


