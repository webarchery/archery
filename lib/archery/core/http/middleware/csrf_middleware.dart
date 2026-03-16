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

/// Middleware that verifies CSRF tokens on state-changing requests.
///
/// `VerifyCsrfToken` protects requests by comparing a token submitted with the
/// request against the CSRF token stored in the user's session cookie.
///
/// Read-only requests are allowed through without verification. Mutating
/// requests must provide a matching token or the middleware responds with
/// `403 Forbidden`.
///
/// Example:
/// ```dart
/// router.post(
///   '/profile',
///   handler: (request) async => profileController.update(request),
///   middleware: [VerifyCsrfToken.middleware],
/// );
/// ```
base class VerifyCsrfToken {
  /// Verifies the CSRF token for the current request before continuing.
  ///
  /// Behavior:
  /// - allows read-only requests through immediately
  /// - extracts the submitted request token
  /// - extracts the session token from the CSRF cookie
  /// - compares both tokens
  /// - rejects the request with `403 Forbidden` when tokens are missing or do
  ///   not match
  ///
  /// Parameters:
  /// - `request`: The incoming HTTP request.
  /// - `next`: The next middleware or handler in the pipeline.
  ///
  /// Example:
  /// ```dart
  /// await VerifyCsrfToken.middleware(request, () async {
  ///   request.response.write('Token accepted');
  /// });
  /// ```
  static Future<dynamic> middleware(
      HttpRequest request,
      Future<void> Function() next,
      ) async {

    if(request.uri.path.startsWith('/api')) {
      return await next();
    }

    if (_isReading(request)) {
      return await next();

    }

    final token = await _getToken(request);

    final sessionToken = await _getSessionToken(request);

    if (token == null || sessionToken == null || token != sessionToken) {
      return request.response
        ..statusCode = HttpStatus.forbidden
        ..write("403 Forbidden: Invalid CSRF Token")
        ..close();
    }

    await next();
  }

  /// Returns `true` when the request method is considered read-only.
  ///
  /// The framework treats `GET`, `HEAD`, and `OPTIONS` requests as safe reads
  /// and skips CSRF verification for them.
  ///
  /// Example:
  /// ```dart
  /// final isReading = VerifyCsrfToken._isReading(request);
  /// print(isReading);
  /// ```
  static bool _isReading(HttpRequest request) {
    return ['GET', 'HEAD', 'OPTIONS'].contains(request.method);
  }

  /// Extracts the CSRF token submitted with the request.
  ///
  /// The current implementation reads the `_token` form input. Header-based
  /// token lookup is noted for future use but is not currently enabled.
  ///
  /// Returns the submitted token when present, otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// final token = await VerifyCsrfToken._getToken(request);
  /// print(token);
  /// ```
  static Future<String?> _getToken(HttpRequest request) async {
    // Check header
    // Todo -current unused, future proofing for jax calls
    // final headerToken = request.headers.value('X-CSRF-TOKEN');
    // if (headerToken != null) return headerToken;

    // Check input
    try {
      final form = request.form();
      final inputToken = await form.input('_token');

      if (inputToken != null) return inputToken.toString();
    } catch (e) {
      // print('CSRF Body Parse Error: $e');
      // print(s);
    }

    return null;
  }

  /// Reads the CSRF token stored in the request cookies.
  ///
  /// The token is loaded from the `archery_csrf_token` cookie.
  ///
  /// Returns the cookie token when present, otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// final sessionToken = await VerifyCsrfToken._getSessionToken(request);
  /// print(sessionToken);
  /// ```
  static Future<String?> _getSessionToken(HttpRequest request) async {
    final cookie = request.cookies.firstWhereOrNull(
          (c) => c.name == 'archery_csrf_token',
    );
    return cookie?.value;
  }
}