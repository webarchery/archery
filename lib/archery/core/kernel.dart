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

/// The core HTTP kernel of the Archery framework.
///
/// Responsible for:
/// - Running global middleware pipeline
/// - Delegating request to the [Router] for route matching
///
/// Acts as the entry point for all incoming [HttpRequest]s.
///
/// **Global Middleware Flow:**
/// ```
/// [AppKernel] → [middleware[0]] → [middleware[1]] → ... → [Router.dispatch]
/// ```
base class AppKernel {
  /// List of global middleware applied to **every** request.
  ///
  /// Executed in order. Each calls `next()` to continue.
  final List<HttpMiddleware> middleware;

  /// The router responsible for route matching and dispatch.
  final Router router;

  /// Creates a new kernel with optional [middleware] and required [router].
  ///
  /// Example:
  /// ```dart
  /// final kernel = AppKernel(
  ///   middleware: [loggingMiddleware, corsMiddleware],
  ///   router: appRouter,
  /// );
  /// ```
  AppKernel({this.middleware = const [], required this.router});

  /// Handles an incoming [HttpRequest] by running global middleware,
  /// then dispatching to the router.
  ///
  /// This is the **main entry point** for HTTP request processing.
  ///
  /// ```dart
  /// HttpServer.bind('0.0.0.0', 8080).then((server) {
  ///   server.listen(kernel.handle);
  /// });
  /// ```
  Future<void> handle(HttpRequest request) async {

    // Buffer the request body to prevent "stream has already been listened to" errors.
    // This allows multiple components (CSRF, Logging, Controllers) to read the body.
    // Only buffer body if content exists to prevent stream issues
    // For GET/HEAD requests with no body, we skip buffering to improve performance
    if (request.contentLength > 0) {
      try {
        await request.form().buffer();
      } catch (e) {
        App().archeryLogger.error("Error buffering request body", {"origin": "Kernel.handle()", "error": e.toString()});
      }
    }

    await _runMiddleware(request, 0);
  }

  /// Recursively executes the global middleware chain.
  ///
  /// - If more middleware exists: run current and pass `next`
  /// - If at end: dispatch to [router]
  Future<void> _runMiddleware(HttpRequest request, int index) async {
    if (index < middleware.length) {
      // Call current middleware with `next` callback
      middleware[index](request, () => _runMiddleware(request, index + 1));
    } else {
      // All middleware passed → route the request
      await router.dispatch(request);
    }
  }
}
