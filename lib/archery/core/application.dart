
import 'package:archery/archery/archery.dart';

enum AppStatus {
  initializing,
  booting,
  ready,
  error,
  shuttingDown
}
class App {


  static final String version = "0.1.0";

  App._internal();

  final List<Provider> _providers = [];
  final List<void Function()> _bootedCallbacks = [];

  AppStatus status = AppStatus.initializing;

  static final App _instance = App._internal();

  factory App() => _instance;


  final ServiceContainer container = Container.root();





  void register(Provider provider) {

    if(_providers.contains(provider)) {
      throw ProviderException.duplicateRegistration(type: provider.runtimeType);
    }
    _providers.add(provider);
    provider.register(container);

  }

  void registerGroup(String groupName, List<Provider> providers) {
    for (final provider in providers) {
      try {
        register(provider);
      } catch(e, stack) {
        throw ProviderException.unregistered(type: provider.runtimeType, trace: stack);
      }

    }
  }

  void onBooted(void Function() callback) {
    _bootedCallbacks.add(callback);
  }

  Future<void> boot() async {
    status = AppStatus.booting;

    // Default Router
    final router = Router();
    container.bindInstance<Router>(router);

    // Default View Engine

    final settings = { "viewsPath": 'lib/src/http/views', "publicPath": 'lib/src/http/public'};
    final engine = TemplateEngine(viewsDirectory: settings['viewsPath']!, publicDirectory:  settings['publicPath']!);
    container.bindInstance<TemplateEngine>(engine);

    // Default Static Files Server
    final staticFilesServer = StaticFilesServer();
    container.bindInstance<StaticFilesServer>(staticFilesServer);


    try {
      for (final provider in _providers) {
        try {
          await provider.boot(container); // async boot support
        } catch(e, stack) {
          throw ProviderException.unbooted(type: provider.runtimeType, trace: stack);
        }

      }
      for (final callback in _bootedCallbacks) {
        callback();
      }

      status = AppStatus.ready;
    } catch (e, stack) {
      status = AppStatus.error;
      print('[App Boot Error] $e\n$stack');
    }
  }

  Future<void> shutdown() async {
    status = AppStatus.shuttingDown;
    print('🛑 Shutting down...');
    // Perform cleanup if needed
  }


  static String generateKey() {
    return base64Url.encode(List.generate(32, (i) => Random.secure().nextInt(256)));
  }

  void setKeys()  {

    final file = File('lib/src/config/app.json');

    // Create file if it doesn't exist
    if (!file.existsSync()) {
      file.createSync(recursive: true);
      file.writeAsStringSync('{}');
    }

    String content = file.readAsStringSync();

    if(content.isEmpty)  content = "{}";

    final config = json.decode(content);

    config["name"] = "Archery Web Application";
    config['version'] = version;
    config["timestamp"] = DateTime.now().toUtc().toIso8601String();
    config['key'] = generateKey();
    config['id'] = Uuid().v4();
    config['debug'] = true;

    file.writeAsStringSync(json.encode(config));


  }

}

extension ContainerOperations on App {

  T resolve<T>() => resolveInstance<T>();
  T make<T>() => resolveInstance<T>();

  T resolveInstance<T>() {
    return container.make<T>();
  }


  T? tryResolve<T>() => tryResolveInstance<T>();
  T? tryMake<T>() => tryResolveInstance<T>();

  T? tryResolveInstance<T>() {
    return container.tryMake<T>();
  }



  void bind<T>(T instance) => bindInstance<T>(instance);
  void bindInstance<T>(T instance) {
    container.bindInstance<T>(instance);
  }
}