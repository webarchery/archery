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
/// Alias for the framework flash-message cleanup middleware.
///
/// This typedef provides a shorter name for referencing the middleware in
/// route or global middleware registration.
///
/// Example:
/// ```dart
/// final middleware = [FlashMessaging.middleware];
/// ```
typedef FlashMessaging = FlashMessagingMiddleware;

/// Middleware that manages the lifecycle of flashed session state across
/// requests.
///
/// This middleware is responsible for clearing temporary session data after
/// it has survived the expected number of request cycles. In practice, this
/// supports common redirect-and-render flows where flashed data needs to be
/// available briefly and then removed.
///
/// Behavior:
/// - skips flash lifecycle handling for `/api/` routes
/// - checks the internal `_flashTrips` counter in the container
/// - clears flashed messages, errors, and old input after two trips
/// - advances the trip counter from `1` to `2` when needed
///
/// Example:
/// ```dart
/// router.get(
///   '/dashboard',
///   handler: (request) async => dashboardController.index(request),
///   middleware: [FlashMessaging.middleware],
/// );
/// ```
class FlashMessagingMiddleware {
  /// Processes flash-message lifecycle state for the current request.
  ///
  /// This middleware uses the `_flashTrips` container binding to determine
  /// whether flashed session data should be preserved or cleared.
  ///
  /// Rules:
  /// - Requests to `/api/` paths bypass flash lifecycle handling.
  /// - When `_flashTrips == 2`, flashed messages, validation errors, and
  ///   old input data are cleared from the session.
  /// - When `_flashTrips == 1`, the middleware promotes the counter to `2`.
  /// - Requests without a `_flashTrips` binding continue normally.
  ///
  /// Parameters:
  /// - `request`: The active HTTP request.
  /// - `next`: The next middleware or handler in the pipeline.
  ///
  /// Example:
  /// ```dart
  /// await FlashMessagingMiddleware.middleware(request, () async {
  ///   request.response.write('Continuing request pipeline');
  /// });
  /// ```
  static Future<dynamic> middleware(HttpRequest request, Future<void> Function() next) async {

    if(request.uri.path.startsWith('/api/')) {
      return await next();
    }

    final flashTrip = App().container.tryMake<int>(name: "_flashTrips");

    if (flashTrip != null) {
      App().container.disposeBinding<int>(name: "_flashTrips");
      if (flashTrip == 2) {
        request.thisSession?.flashMessages = {};
        request.thisSession?.errors = {};
        request.thisSession?.data = {};
      } else if (flashTrip == 1) {
        App().container.bindInstance<int>(name: "_flashTrips", 2);
      }
    }

    await next();
  }
}
