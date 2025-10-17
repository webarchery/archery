

typedef FactoryFunction<T> = T Function(ServiceContainer container, [Map<String, dynamic>? options]);

abstract class ServiceContainer {

  void bind<T>({String? name, required FactoryFunction<T> factory});
  void singleton<T>({String? name, required FactoryFunction<T> factory,  bool eager = false});
  void bindInstance<T>(T instance, {String? name});

  bool contains<T>({String? name});
  T make<T>({String? name, Map<String, dynamic>? options});
  T? tryMake<T>({String? name, Map<String, dynamic>? options});


  Future<void> dispose();

  ServiceContainer newScope();
  Map<String, List<String>> listRegistrations();

  Future<void> initialize();
  Future<void> allReady() async {}

  void onDispose(Future<void> Function() callback);

}

class ServiceContainerException implements Exception {

  final Type type;
  final String? name;
  final String? message;

  ServiceContainerException({required this.type, this.name, this.message});

  ServiceContainerException.duplicateRegistration({required this.type, this.name}) : message = "Duplicate registration of type($type) ${name != null ? ' with name($name)' : ''}";
  ServiceContainerException.circularDependencyResolution({required this.type, this.name}) : message = "Circular resolution of type($type) ${name != null ? ' with name($name)' : ''}";
  ServiceContainerException.registrationNotFound({required this.type, this.name}) : message = "No registration for type($type) ${name != null ? ' with name($name)' : ''} in container or parent scopes";
  ServiceContainerException.nullInstanceUnallowed({required this.type, this.name}) : message = "Instance cannot be null for type($type) ${name != null ? ' with name($name)' : ''} in container or parent scopes";

  @override
  String toString() {
    return "$message";
  }

}

class Container implements ServiceContainer {

  final Container? _parent;

  final Map<String, dynamic Function(Container, [Map<String, dynamic>?])>
  _factories = {};

  final Map<String, Object> _singletons = {};

  final Map<String, bool> _eagerRegistrations = {};

  final List<Future<void> Function()> _disposers = [];

  final List<Future<void>> _ready = [];



  Container._([this._parent]);

  factory Container.root() {
    final rootContainer = Container._(null);
    rootContainer.bindInstance<ServiceContainer>(rootContainer);
    rootContainer.bindInstance<Container>(rootContainer);
    return rootContainer;
  }

  String _key<T>([String? name]) {
    if (name == null || name.isEmpty) {
      return "$T";
    }
    return "$T -> $name";
  }



  T _resolve<T>(String key, Set<String> resolutionStack, [Map<String, dynamic>? options, bool propagate = true]) {

    if (resolutionStack.contains(key)) {
      throw ServiceContainerException.circularDependencyResolution(type: T , name: key.split('-> ').last);
    }

    resolutionStack.add(key);

    try {

      // Already constructed singleton?
      if (_singletons.containsKey(key)) {
        return _singletons[key] as T;
      }

      // Factory present?
      final factory = _factories[key];

      if (factory != null) {
        final instance = factory(this, options) as T;


        if (_eagerRegistrations[key] != true) {
          _singletons[key] = instance as Object;
        }
        return instance;
      }


      if(propagate) {
        if (_parent != null) {
          return _parent._resolve<T>(key, {}, options);
        }
      }

      throw ServiceContainerException.registrationNotFound(type: T, name: key.split('-> ').last);

    } finally {
      resolutionStack.remove(key);
    }
  }

  @override
  Future<void> allReady() async {
    await Future.wait(_ready);
  }

  @override
  void bind<T>({String? name, required T Function(ServiceContainer container, Map<String, dynamic>? options) factory}) {

    final key = _key<T>(name);

    if (_factories.containsKey(key) || _singletons.containsKey(key)) {
      throw ServiceContainerException.duplicateRegistration(type: T, name: name);
    }

    _factories[key] = (container, [options]) => factory(container, options);

  }

  @override
  void bindInstance<T>(T instance, {String? name}) {
    final key = _key<T>(name);

    if (_factories.containsKey(key) || _singletons.containsKey(key)) {
      throw ServiceContainerException.duplicateRegistration(type: T, name: name);
    }

    if (instance == null) {
      throw ServiceContainerException.nullInstanceUnallowed(type: T, name: name);
    }

    _singletons[key] = instance as Object;
  }

  @override
  bool contains<T>({String? name}) {
    final key = _key<T>(name);
    return _factories.containsKey(key) ||
        _singletons.containsKey(key) ||
        (_parent?.contains<T>(name: name) ?? false);
  }

  @override
  Future<void> dispose() async {
    for (final disposer in _disposers.reversed) {
      await disposer();
    }

    _disposers.clear();
    _singletons.clear();
    _factories.clear();
    _ready.clear();
    _eagerRegistrations.clear();
  }

  @override
  Future<void> initialize() async {
    for (final key in _eagerRegistrations.keys) {
      if (_singletons.containsKey(key)) continue;
      final factory = _factories[key];
      if (factory != null) {
        _singletons[key] = factory(this) as Object;
      }
    }
  }

  @override
  Map<String, List<String>> listRegistrations() {
    final registrations = <String, List<String>>{
      "factories": _factories.keys.toList(),
      "singletons": _singletons.keys.toList(),
      'eager': _eagerRegistrations.keys.toList()
    };

    if (_parent != null) {
      final parentRegistrations = _parent.listRegistrations();
      registrations['parent_factories'] = parentRegistrations['factories'] ?? [];
      registrations['parent_singletons'] =
          parentRegistrations['singletons'] ?? [];
      registrations['parent_eager'] = parentRegistrations['eager'] ?? [];
    }

    return registrations;
  }

  @override
  T make<T>({String? name, Map<String, dynamic>? options}) {
    return _resolve<T>(_key<T>(name), {}, options);
  }

  @override
  ServiceContainer newScope() => Container._(this);

  @override
  void onDispose(Future<void> Function() callback) {
    _disposers.add(callback);
  }

  @override
  void singleton<T>({String? name, required T Function(ServiceContainer container, [Map<String, dynamic>? options]) factory,  bool eager = false }) {
    final key = _key<T>(name);

    if (_factories.containsKey(key) || _singletons.containsKey(key)) {
      throw ServiceContainerException.duplicateRegistration(type: T, name: name);

    }

    if (eager) {
      _eagerRegistrations[key] = true;
      _factories[key] = (container, [options]) => factory(container, options);
    } else {
      _factories[key] = (container, [options]) =>
      _singletons.putIfAbsent(key, () => factory(container, options) as Object)
      as T;
    }
  }

  @override
  T? tryMake<T>({String? name, Map<String, dynamic>? options}) {
    return contains<T>(name: name) ? make<T>(name: name, options : options) : null;
  }

}