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

/// Secure password hashing utility using **PBKDF2-SHA256**.
///
/// Features:
/// - 100,000 iterations (configurable via `_iterations`)
/// - 16-byte cryptographically secure salt
/// - 256-bit derived key
/// - Constant-time verification
/// - Standard hash format: `$pbkdf2-sha256$iterations$salt$hash`
///
/// **Security:**
/// - Uses `Random.secure()` for salt generation
/// - HMAC-SHA256 with proper key padding
/// - Constant-time string comparison
///
/// **Example:**
/// ```dart
/// final hash = Hasher.hashPassword('mySecret123');
/// final isValid = Hasher.verifyPassword('mySecret123', hash); // true
/// ```
base class Hasher {
  /// Length of the random salt in bytes.
  static const int _saltLength = 16;

  /// Number of PBKDF2 iterations (higher = slower = more secure).
  /// Adjusted to 25,000 for pure Dart performance (~200ms).
  static const int _iterations = 25000;

  /// Length of the derived key in bytes (256 bits).
  static const int _keyLength = 32;

  /// Generates a cryptographically secure random salt.
  ///
  /// Returns URL-safe base64-encoded string.
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(_saltLength, (i) => random.nextInt(256));
    return base64Url.encode(saltBytes);
  }

  /// HMAC-SHA256 implementation.
  ///
  /// Follows RFC 2104:
  /// ```
  /// H(K XOR opad, H(K XOR ipad, text))
  /// ```
  static List<int> _hmacSha256(List<int> key, List<int> data) {
    const blockSize = 64; // SHA-256 block size in bytes

    // Key must be <= blockSize; hash if longer
    if (key.length > blockSize) {
      key = sha256.convert(key).bytes;
    }

    // Pad key to blockSize with zeros
    if (key.length < blockSize) {
      key = List<int>.from(key)..addAll(List.filled(blockSize - key.length, 0));
    }

    // Create inner and outer pads
    final ipad = List<int>.generate(blockSize, (i) => key[i] ^ 0x36);
    final opad = List<int>.generate(blockSize, (i) => key[i] ^ 0x5C);

    // inner = H(ipad || data)
    final innerHash = sha256.convert([...ipad, ...data]).bytes;
    // outer = H(opad || inner)
    final outerHash = sha256.convert([...opad, ...innerHash]).bytes;

    return outerHash;
  }

  /// Implements PBKDF2 using HMAC-SHA256.
  ///
  /// Derives a key from [password] and [salt] using [iterations].
  /// Returns first [keyLength] bytes of derived key.
  static List<int> _pbkdf2(String password, String salt, int iterations, int keyLength) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);

    final hLen = 32; // SHA-256 output length
    final l = (keyLength + hLen - 1) ~/ hLen; // Number of blocks needed
    final result = <int>[];

    for (var i = 1; i <= l; i++) {
      // F(P, S, c, i) = U1 XOR U2 XOR ... XOR Uc
      final block = List<int>.from(saltBytes)..addAll([(i >> 24) & 0xFF, (i >> 16) & 0xFF, (i >> 8) & 0xFF, i & 0xFF]);

      var u = _hmacSha256(passwordBytes, block);
      final temp = List<int>.from(u); // This will be XORed iteratively

      for (var j = 1; j < iterations; j++) {
        u = _hmacSha256(passwordBytes, u);
        for (var k = 0; k < u.length; k++) {
          temp[k] ^= u[k];
        }
      }

      result.addAll(temp);
    }

    return result.sublist(0, keyLength);
  }

  /// Hashes a password securely.
  ///
  /// Returns a string in the format:
  /// ```
  /// $pbkdf2-sha256$100000$<salt>$<hash>
  /// ```
  ///
  /// Example:
  /// ```dart
  /// final hash = Hasher.make('password123');
  /// // → $pbkdf2-sha256$100000$abc123...$xyz789...
  /// ```
  static String _hash(String password) {
    final salt = _generateSalt();
    final key = _pbkdf2(password, salt, _iterations, _keyLength);
    final keyB64 = base64Url.encode(key);

    return '\$pbkdf2-sha256\$$_iterations\$$salt\$$keyB64';
  }

  /// Verifies a password against a stored hash.
  ///
  /// - Returns `true` if password matches
  /// - Returns `false` on invalid format, mismatch, or error
  /// - Uses **constant-time comparison** to prevent timing attacks
  ///
  /// Example:
  /// ```dart
  /// final valid = Hasher.verifyPassword('input', storedHash);
  /// ```
  static bool _verify(String password, String? storedHash) {
    if (storedHash == null) return false;

    try {
      final parts = storedHash.split('\$');
      if (parts.length != 5 || parts[1] != 'pbkdf2-sha256') {
        throw const FormatException('Invalid hash format');
      }

      final iterations = int.parse(parts[2]);
      final salt = parts[3];
      final storedKeyB64 = parts[4];

      final computedKey = _pbkdf2(password, salt, iterations, _keyLength);
      final computedKeyB64 = base64Url.encode(computedKey);

      return _constantTimeCompare(storedKeyB64, computedKeyB64);
    } catch (e) {
      return false;
    }
  }

  /// Compares two strings in constant time.
  ///
  /// Prevents timing attacks by always comparing full length.
  static bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }


  // These method name are generic for the idea
  // hashPassword/verifyPassword are DX convenient

  static String make(String key) {
    return _hash(key);
  }

  // Hasher.check() vs Hasher.verify()
  static bool check(String key, String? hash) {
    return _verify(key, hash);
  }
}
