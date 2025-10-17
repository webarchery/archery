import 'package:archery/archery/archery.dart';

class ProviderException implements Exception {
  final Type type;
  final String? message;
  final StackTrace? trace;

  ProviderException({ required this.type, this.message, this.trace });

  ProviderException.duplicateRegistration({required this.type, this.trace}) : message = "Duplicate provider registration of $type";
  ProviderException.unbooted({required this.type, this.trace}) : message = "$type boot() method failed during APP initialization";
  ProviderException.unregistered({required this.type, this.trace}) : message = "$type register() method failed during APP initialization";

  @override
  String toString() {
    return "$message ?? $type ${trace?.toString()}";
  }

}
abstract class Provider {
  void register(ServiceContainer container);
  Future<void> boot(ServiceContainer container) async {}
}
