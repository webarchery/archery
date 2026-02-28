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

import 'package:archery/archery/archery.dart';

/// Exception thrown during service provider lifecycle.
///
/// Covers:
/// - Duplicate registration
/// - Failed `register()`
/// - Failed `boot()`
///
/// Provides structured context for debugging initialization issues.
base class ProviderException implements Exception {
  /// The [Provider] type that caused the exception.
  final Type type;

  /// Human-readable error message.
  final String? message;

  /// Optional stack trace from the failure point.
  final StackTrace? trace;

  /// Generic constructor.
  ProviderException({required this.type, this.message, this.trace});

  /// Thrown when a provider is registered more than once.
  ///
  /// Example:
  /// ```dart
  /// throw ProviderException.duplicateRegistration(type: MyProvider);
  /// ```
  factory ProviderException.duplicateRegistration({
    required Type type,
    StackTrace? trace,
  }) {
    return ProviderException(
      type: type,
      message: 'Duplicate provider registration of $type',
      trace: trace,
    );
  }

  /// Thrown when a provider's `boot()` method throws during app startup.
  factory ProviderException.unbooted({required Type type, StackTrace? trace}) {
    return ProviderException(
      type: type,
      message: '$type boot() method failed during APP initialization',
      trace: trace,
    );
  }

  /// Thrown when a provider's `register()` method throws during registration.
  factory ProviderException.unregistered({
    required Type type,
    StackTrace? trace,
  }) {
    return ProviderException(
      type: type,
      message: '$type register() method failed during APP initialization',
      trace: trace,
    );
  }

  /// String representation for logging and debugging.
  ///
  /// Format: `message` or `type` + optional stack trace.
  @override
  String toString() {
    final msg = message ?? '$type';
    return trace != null ? '$msg\n$trace' : msg;
  }
}

/// Abstract base class for service providers.
///
/// Providers are used to:
/// - Register services into the [ServiceContainer]
/// - Perform boot-time initialization (e.g., route registration, event listeners)
///
/// **Lifecycle:**
/// 1. `register(container)` — bind services
/// 2. `boot(container)` — perform startup logic (async)
///
/// Example:
/// ```dart
/// class RouteServiceProvider extends Provider {
///   @override
///   void register(ServiceContainer container) {
///     container.bindInstance<MyService>(MyService());
///   }
///
///   @override
///   Future<void> boot(ServiceContainer container) async {
///     final router = container.make<Router>();
///     router.get('/health', (req) async => req.respond('OK'));
///   }
/// }
/// ```
abstract class Provider {
  /// Registers services, bindings, or singletons into the container.
  ///
  /// Called **synchronously** during app initialization.
  ///
  /// Should **not** perform async operations or depend on booted services.
  Future<void> register(ServiceContainer container) async {}

  /// Performs asynchronous boot-time initialization.
  ///
  /// Called **after all providers have registered**.
  ///
  /// Safe to:
  /// - Register routes
  /// - Set up event listeners
  /// - Perform database migrations
  /// - Resolve and configure services
  ///
  /// Default implementation does nothing.
  Future<void> boot(ServiceContainer container) async {}
}
