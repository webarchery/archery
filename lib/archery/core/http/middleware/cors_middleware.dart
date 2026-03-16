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

/// Alias for the framework CORS middleware.
///
/// This typedef allows the middleware to be referenced using the shorter
/// `Cors` name in route and middleware declarations.
///
/// Example:
/// ```dart
/// router.get(
///   '/api/users',
///   handler: (request) async => index(request),
///   middleware: [Cors.middleware],
/// );
/// ```
typedef Cors = CorsMiddleware;

/// Middleware that applies Cross-Origin Resource Sharing (CORS) headers
/// to outgoing responses.
///
/// This middleware:
/// - allows requests from any origin
/// - permits `GET`, `POST`, `PUT`, `DELETE`, and `OPTIONS` methods
/// - allows the `Content-Type` and `Range` request headers
/// - exposes `Content-Length` and `Content-Range` response headers
/// - short-circuits preflight `OPTIONS` requests
///
/// This type is intended for use in route or global middleware pipelines.
///
/// Example:
/// ```dart
/// await CorsMiddleware.middleware(request, () async {
///   request.response.write('OK');
/// });
/// ```
base class CorsMiddleware {
  /// Applies CORS headers to the response and handles preflight requests.
  ///
  /// For all requests, this method sets the standard response headers used by
  /// the framework's default CORS policy.
  ///
  /// If the incoming request method is `OPTIONS`, the middleware responds with
  /// `200 OK`, closes the response, and does not continue the pipeline.
  ///
  /// For all other request methods, control is passed to [next].
  ///
  /// Parameters:
  /// - `request`: The active HTTP request.
  /// - `next`: The next middleware or route handler in the pipeline.
  ///
  /// Example:
  /// ```dart
  /// await CorsMiddleware.middleware(request, () async {
  ///   request.response.write(jsonEncode({'status': 'ok'}));
  /// });
  /// ```
  static Future<dynamic> middleware(
    HttpRequest request,
    Future<void> Function() next,
  ) async {
    // Add CORS headers to response
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type, Range')
      ..set('Access-Control-Expose-Headers', 'Content-Length, Content-Range');

    // Handle preflight OPTIONS request
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    await next();
  }
}
