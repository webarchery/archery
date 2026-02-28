// SPDX-FileCopyrightText: 2025 Kwame, III <webarcherydev@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// https://webarchery.dev

/// A lightweight, hierarchical **Dependency Injection (DI) container** for Dart/Flutter.
///
/// Supports:
/// - **Transient** services via [bind]
/// - **Singleton** services via [singleton] (lazy or eager)
/// - **Instance binding** via [bindInstance]
/// - **Scoped containers** via [newScope]
/// - **Lifecycle management** with [initialize], [allReady], [dispose], and [onDispose]
/// - **Named registrations** and **options** for flexible configuration
/// - **Circular dependency detection** and **safe resolution** with [tryMake]
///
/// ## Example
///
/// ```dart
/// final container = Container.root();
///
/// container.bind<Logger>((c, _) => ConsoleLogger());
/// container.singleton<Database>(
///   factory: (c, _) => Database.connect(),
///   eager: true,
/// );
///
/// await container.initialize();
///
/// final logger = container.make<Logger>();
/// ```
abstract class ServiceContainer {
  /// Registers a **transient** service.
  ///
  /// A new instance is created every time [make] is called.
  ///
  /// ```dart
  /// container.bind<Logger>((c, _) => ConsoleLogger());
  /// final logger1 = container.make<Logger>(); // New instance
  /// final logger2 = container.make<Logger>(); // Different instance
  /// ```
  ///
  /// - `name`: Optional identifier for multiple implementations of the same type.
  /// - `factory`: Function that creates the instance.
  ///
  /// Throws [ServiceContainerException.duplicateRegistration] if already registered.
  void bind<T>({String? name, required FactoryFunction<T> factory});

  /// Disposes a binding
  ///
  Future<bool> disposeBinding<T>({String? name});

  /// Registers a **singleton** service.
  ///
  /// The same instance is returned for all [make] calls within the same scope.
  ///
  /// ```dart
  /// container.singleton<Database>(factory: (c, _) => Database.connect());
  /// final db1 = container.make<Database>();
  /// final db2 = container.make<Database>();
  /// expect(identical(db1, db2), true);
  /// ```
  ///
  /// - `eager: true` → instance is created during [initialize]
  /// - `eager: false` (default) → lazy creation on first [make]
  ///
  /// Throws [ServiceContainerException.duplicateRegistration] if already registered.
  void singleton<T>({
    String? name,
    required FactoryFunction<T> factory,
    bool eager = false,
  });

  /// Binds an **existing instance** to the container.
  ///
  /// The provided instance is returned for all [make] calls.
  ///
  /// ```dart
  /// final repo = UserRepositoryImpl();
  /// container.bindInstance<UserRepository>(repo);
  /// ```
  ///
  /// Throws:
  /// - [ServiceContainerException.duplicateRegistration] if already registered
  /// - [ServiceContainerException.nullInstanceUnallowed] if `instance` is `null`
  void bindInstance<T>(T instance, {String? name});

  /// Checks if a service is registered in this container or any parent scope.
  ///
  /// ```dart
  /// if (container.contains<Logger>()) {
  ///   final logger = container.make<Logger>();
  /// }
  /// ```
  bool contains<T>({String? name});

  /// Resolves a service instance.
  ///
  /// Throws [ServiceContainerException.registrationNotFound] if not registered.
  ///
  /// ```dart
  /// final logger = container.make<Logger>();
  /// final namedLogger = container.make<Logger>(name: 'file');
  /// final withOptions = container.make<ApiClient>(options: {'url': 'https://api.com'});
  /// ```
  T make<T>({String? name, Map<String, dynamic>? options});

  /// Safely resolves a service. Returns `null` if not registered.
  ///
  /// ```dart
  /// final logger = container.tryMake<Logger>();
  /// if (logger != null) { ... }
  /// ```
  T? tryMake<T>({String? name, Map<String, dynamic>? options});

  /// Disposes all singletons and runs disposal callbacks in reverse order.
  ///
  /// Should be called during app shutdown or test teardown.
  ///
  /// ```dart
  /// await container.dispose();
  /// ```
  Future<void> dispose();

  /// Creates a **child scope** that inherits parent bindings but isolates singletons.
  ///
  /// Useful for per-request or per-feature isolation.
  ///
  /// ```dart
  /// final requestScope = container.newScope();
  /// requestScope.bindInstance<Request>(currentRequest);
  /// ```
  ServiceContainer newScope();

  /// Returns a map of all registrations for debugging and introspection.
  ///
  /// ```dart
  /// {
  ///   'factories': ['Logger', 'ApiClient -> staging'],
  ///   'singletons': ['Database'],
  ///   'eager': ['Database'],
  ///   'parent_factories': [...],
  /// }
  /// ```
  Map<String, List<String>> listRegistrations();

  /// Initializes all **eager** singletons.
  ///
  /// Call early in app lifecycle if using `eager: true`.
  ///
  /// ```dart
  /// await container.initialize();
  /// ```
  Future<void> initialize();

  /// Waits for all async initialization tasks to complete.
  ///
  /// Useful when factories return `Future<T>`.
  ///
  /// ```dart
  /// await container.allReady();
  /// ```
  Future<void> allReady() async {}

  /// Registers an async cleanup callback to run during [dispose].
  ///
  /// Callbacks are executed in **reverse order** of registration.
  ///
  /// ```dart
  /// container.onDispose(() async {
  ///   await analytics.flush();
  /// });
  /// ```
  void onDispose(Future<void> Function() callback);
}

/// Function type for creating service instances.
///
/// The container and optional runtime options are provided.
///
/// ```dart
/// T Function(ServiceContainer container, [Map<String, dynamic>? options])
/// ```
///
/// Async factories should return `Future<T>`.
typedef FactoryFunction<T> =
    T Function(ServiceContainer container, [Map<String, dynamic>? options]);

/// Exception thrown by [ServiceContainer] operations.
base class ServiceContainerException implements Exception {
  final Type type;
  final String? name;
  final String? message;

  ServiceContainerException({required this.type, this.name, this.message});

  /// Thrown when registering a type/name that's already bound.
  ServiceContainerException.duplicateRegistration({
    required this.type,
    this.name,
  }) : message =
           "Duplicate registration of type($type)${name != null ? ' with name($name)' : ''}";

  /// Thrown when a circular dependency is detected during resolution.
  ServiceContainerException.circularDependencyResolution({
    required this.type,
    this.name,
  }) : message =
           "Circular resolution of type($type)${name != null ? ' with name($name)' : ''}";

  /// Thrown when [make] is called for an unregistered service.
  ServiceContainerException.registrationNotFound({required this.type, this.name})
    : message =
          "No registration for type($type)${name != null ? ' with name($name)' : ''} in container or parent scopes";

  /// Thrown when [bindInstance] is called with a `null` instance.
  ServiceContainerException.nullInstanceUnallowed({
    required this.type,
    this.name,
  }) : message =
           "Instance cannot be null for type($type)${name != null ? ' with name($name)' : ''} in container or parent scopes";

  @override
  String toString() => message ?? 'ServiceContainerException';
}

/// Concrete implementation of [ServiceContainer].
///
/// Use [Container.root] to create the root container.
base class Container implements ServiceContainer {
  final Container? _parent;
  final List<Future<void>> _ready = [];
  final Map<String, Object> _singletons = {};
  final Map<String, bool> _eagerRegistrations = {};
  final List<Future<void> Function()> _disposers = [];
  final Map<String, dynamic Function(Container, [Map<String, dynamic>?])>
  _factories = {};

  /// Private constructor for internal use and scoping.
  Container._([this._parent]);

  /// Creates the **root container** and auto-registers itself.
  ///
  /// The root container is automatically bound as:
  /// - [ServiceContainer]
  /// - [Container]
  ///
  /// ```dart
  /// final container = Container.root();
  /// expect(container.make<Container>(), same(container));
  /// ```
  factory Container.root() {
    final rootContainer = Container._(null);
    rootContainer.bindInstance<ServiceContainer>(rootContainer);
    rootContainer.bindInstance<Container>(rootContainer);
    return rootContainer;
  }

  /// Generates a unique key for a type and optional name.
  ///
  /// Format: `"Type"` or `"Type -> name"`
  String _key<T>([String? name]) {
    if (name == null || name.isEmpty) {
      return "$T";
    }
    return "$T -> $name";
  }

  /// Internal resolution logic with circular dependency tracking.
  ///
  /// - Checks for existing singleton
  /// - Executes factory if registered
  /// - Propagates to parent if not found
  /// - Throws appropriate exceptions
  T _resolve<T>(
    String key,
    Set<String> resolutionStack, [
    Map<String, dynamic>? options,
    bool propagate = true,
  ]) {
    if (resolutionStack.contains(key)) {
      throw ServiceContainerException.circularDependencyResolution(
        type: T,
        name: key.split('-> ').last,
      );
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

      if (propagate && _parent != null) {
        return _parent._resolve<T>(key, {}, options);
      }

      throw ServiceContainerException.registrationNotFound(
        type: T,
        name: key.split('-> ').last,
      );
    } finally {
      resolutionStack.remove(key);
    }
  }

  /// Waits for all async initialization tasks.
  ///
  /// Populated by async factories during eager initialization.
  @override
  Future<void> allReady() async {
    await Future.wait(_ready);
  }

  /// Registers a transient factory.
  ///
  /// See [ServiceContainer.bind] for details.
  @override
  void bind<T>({
    String? name,
    required T Function(
      ServiceContainer container,
      Map<String, dynamic>? options,
    )
    factory,
  }) {
    final key = _key<T>(name);

    if (_factories.containsKey(key) || _singletons.containsKey(key)) {
      throw ServiceContainerException.duplicateRegistration(
        type: T,
        name: name,
      );
    }

    _factories[key] = (container, [options]) => factory(container, options);
  }

  /// Binds an existing instance.
  ///
  /// See [ServiceContainer.bindInstance] for details.
  @override
  void bindInstance<T>(T instance, {String? name}) {
    final key = _key<T>(name);

    if (_factories.containsKey(key) || _singletons.containsKey(key)) {
      throw ServiceContainerException.duplicateRegistration(
        type: T,
        name: name,
      );
    }

    if (instance == null) {
      throw ServiceContainerException.nullInstanceUnallowed(
        type: T,
        name: name,
      );
    }

    _singletons[key] = instance as Object;
  }

  /// Checks registration in this container and parents.
  ///
  /// See [ServiceContainer.contains] for details.
  @override
  bool contains<T>({String? name}) {
    final key = _key<T>(name);
    return _factories.containsKey(key) ||
        _singletons.containsKey(key) ||
        (_parent?.contains<T>(name: name) ?? false);
  }

  /// Disposes resources and runs cleanup callbacks.
  ///
  /// See [ServiceContainer.dispose] for details.
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

  /// remove a binding from the container
  /// dispose-> a container
  /// disposeBinding -> a container-binding
  @override
  Future<bool> disposeBinding<T>({String? name}) async {
    final binding = tryMake<T>(name: name);

    if (binding != null) {
      _factories.removeWhere((key, value) => value == binding as Object);
      _singletons.removeWhere((key, value) => value == binding as Object);
      _eagerRegistrations.removeWhere((key, value) => key == T.toString());

      return true;
    }
    return false;
  }

  /// Initializes eager singletons.
  ///
  /// See [ServiceContainer.initialize] for details.
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

  /// Returns registration metadata.
  ///
  /// See [ServiceContainer.listRegistrations] for details.
  @override
  Map<String, List<String>> listRegistrations() {
    final registrations = <String, List<String>>{
      "factories": _factories.keys.toList(),
      "singletons": _singletons.keys.toList(),
      'eager': _eagerRegistrations.keys.toList(),
    };

    if (_parent != null) {
      final parentRegistrations = _parent.listRegistrations();
      registrations['parent_factories'] =
          parentRegistrations['factories'] ?? [];
      registrations['parent_singletons'] =
          parentRegistrations['singletons'] ?? [];
      registrations['parent_eager'] = parentRegistrations['eager'] ?? [];
    }

    return registrations;
  }

  /// Resolves a service.
  ///
  /// See [ServiceContainer.make] for details.
  @override
  T make<T>({String? name, Map<String, dynamic>? options}) {
    return _resolve<T>(_key<T>(name), {}, options);
  }

  /// Creates a child scope.
  ///
  /// See [ServiceContainer.newScope] for details.
  @override
  ServiceContainer newScope() => Container._(this);

  /// Registers a disposal callback.
  ///
  /// See [ServiceContainer.onDispose] for details.
  @override
  void onDispose(Future<void> Function() callback) {
    _disposers.add(callback);
  }

  /// Registers a singleton with optional eager loading.
  ///
  /// See [ServiceContainer.singleton] for details.
  @override
  void singleton<T>({
    String? name,
    required T Function(
      ServiceContainer container, [
      Map<String, dynamic>? options,
    ])
    factory,
    bool eager = false,
  }) {
    final key = _key<T>(name);

    if (_factories.containsKey(key) || _singletons.containsKey(key)) {
      throw ServiceContainerException.duplicateRegistration(
        type: T,
        name: name,
      );
    }

    if (eager) {
      _eagerRegistrations[key] = true;
      _factories[key] = (container, [options]) => factory(container, options);
    } else {
      _factories[key] = (container, [options]) =>
          _singletons.putIfAbsent(
                key,
                () => factory(container, options) as Object,
              )
              as T;
    }
  }

  /// Safely resolves a service.
  ///
  /// See [ServiceContainer.tryMake] for details.
  @override
  T? tryMake<T>({String? name, Map<String, dynamic>? options}) {
    return contains<T>(name: name)
        ? make<T>(name: name, options: options)
        : null;
  }
}
