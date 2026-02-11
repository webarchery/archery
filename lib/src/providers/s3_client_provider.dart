import 'package:archery/archery/archery.dart';

base class S3ClientProvider implements Provider {
  @override
  Future<void> boot(ServiceContainer container) async {}

  @override
  Future<void> register(ServiceContainer container) async {
    try {
      final s3Config = S3Config.fromMap(App().config.get('env.aws'));
      final s3Client = S3Client(s3Config, debug: true);
      container.bindInstance<S3Client>(s3Client);
    } catch (e, s) {
      await App().archeryLogger.error('S3 Client Init Error', {"error": e.toString(), "stack": s.toString(), "hint": "create env.json in config folder, and add aws credentials, or comment out."});
    }

  }

}