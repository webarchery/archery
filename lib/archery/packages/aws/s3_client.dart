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

/// Configuration required to connect to an S3-compatible object store.
///
/// `S3Config` contains credentials, bucket selection, region, and an optional
/// endpoint override.
///
/// Example:
/// ```dart
/// final config = S3Config(
///   key: 'AKIA...',
///   secret: 'super-secret',
///   bucket: 'my-app-bucket',
///   region: 'us-east-1',
/// );
/// ```
base class S3Config {
  /// Access key used to sign S3 requests.
  final String key;

  /// Secret key used to derive AWS Signature Version 4 signatures.
  final String secret;

  /// Bucket name targeted by the client.
  final String bucket;

  /// Region used in the credential scope and default host construction.
  final String region;

  /// Optional custom endpoint for S3-compatible providers.
  final String? endpoint;

  /// Creates an S3 configuration object.
  ///
  /// When [region] is omitted, it defaults to `us-east-1`.
  ///
  /// Example:
  /// ```dart
  /// final config = S3Config(
  ///   key: env['S3_KEY']!,
  ///   secret: env['S3_SECRET']!,
  ///   bucket: env['S3_BUCKET']!,
  /// );
  /// ```
  S3Config({required this.key, required this.secret, required this.bucket, this.endpoint, this.region = 'us-east-1'});

  /// Creates an [S3Config] from a map.
  ///
  /// Expected keys:
  /// - `key`
  /// - `secret`
  /// - `bucket`
  /// - `region` (optional)
  ///
  /// Example:
  /// ```dart
  /// final config = S3Config.fromMap({
  ///   'key': 'AKIA...',
  ///   'secret': 'super-secret',
  ///   'bucket': 'my-app-bucket',
  ///   'region': 'us-west-2',
  /// });
  /// ```
  factory S3Config.fromMap(Map<String, dynamic> map) {
    return S3Config(key: map['key'], secret: map['secret'], bucket: map['bucket'], region: map['region'] ?? 'us-east-1');
  }
}

/// Low-level S3 client responsible for signing and sending HTTP requests.
///
/// `S3Client` implements the AWS Signature Version 4 flow used by S3-compatible
/// services and exposes internal helpers used by higher-level S3 operations.
///
/// Example:
/// ```dart
/// final client = S3Client(
///   S3Config(
///     key: 'AKIA...',
///     secret: 'super-secret',
///     bucket: 'my-app-bucket',
///   ),
/// );
/// ```
base class S3Client {
  /// Runtime S3 configuration.
  final S3Config config;

  /// AWS service name used in the signing scope.
  final String _service = 's3';

  /// Whether debug behavior is enabled.
  final bool debug;

  /// Creates a new S3 client.
  ///
  /// Example:
  /// ```dart
  /// final client = S3Client(config, debug: false);
  /// ```
  S3Client(this.config, {this.debug = true});

  /// Returns a date string formatted as `YYYYMMDD`.
  ///
  /// This value is used in the AWS credential scope.
  ///
  /// Example:
  /// ```dart
  /// final date = client._getDateString(DateTime.utc(2026, 3, 16));
  /// print(date); // 20260316
  /// ```
  String _getDateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  /// Generates the AWS Signature Version 4 signature for a string to sign.
  ///
  /// Parameters:
  /// - `stringToSign`: The canonical string to sign.
  /// - `dateString`: The scope date in `YYYYMMDD` format.
  ///
  /// Example:
  /// ```dart
  /// final signature = client._generateSignature(
  ///   stringToSign: 'AWS4-HMAC-SHA256\n...',
  ///   dateString: '20260316',
  /// );
  /// ```
  String _generateSignature({required String stringToSign, required String dateString /*YYYYMMDD format*/}) {
    final keyDate = Hmac(sha256, utf8.encode('AWS4${config.secret}')).convert(utf8.encode(dateString)).bytes;

    final keyRegion = Hmac(sha256, keyDate).convert(utf8.encode(config.region)).bytes;

    final keyService = Hmac(sha256, keyRegion).convert(utf8.encode(_service)).bytes;

    final keySigning = Hmac(sha256, keyService).convert(utf8.encode('aws4_request')).bytes;

    final signature = Hmac(sha256, keySigning).convert(utf8.encode(stringToSign)).toString();

    return signature;
  }

  /// Builds the `Authorization` header for a signed S3 request.
  ///
  /// This method:
  /// - canonicalizes the provided headers
  /// - builds the canonical request
  /// - builds the string to sign
  /// - generates the final signature
  ///
  /// Example:
  /// ```dart
  /// final authHeader = client._generateAuthHeader(
  ///   method: 'PUT',
  ///   path: '/uploads/avatar.png',
  ///   datetime: 'Mon, 16 Mar 2026 12:00:00 GMT',
  ///   dateString: '20260316',
  ///   headers: {
  ///     'host': 'my-bucket.s3.us-east-1.amazonaws.com',
  ///     'x-amz-date': 'Mon, 16 Mar 2026 12:00:00 GMT',
  ///     'x-amz-content-sha256': 'abc123',
  ///   },
  ///   canonicalQueryString: '',
  ///   payloadHash: 'abc123',
  /// );
  /// ```
  String _generateAuthHeader({
    required String method,
    required String path,
    required String datetime,
    required String dateString,
    required Map<String, String> headers,
    required String canonicalQueryString,
    required String payloadHash,
  }) {
    // Build canonical headers
    final canonicalHeaders = headers.entries.map((e) => '${e.key.toLowerCase()}:${e.value.trim()}').toList()..sort();

    final signedHeaders = canonicalHeaders.map((h) => h.split(':')[0]).toList().join(';');

    // Build canonical request
    final canonicalRequest = [method, path, canonicalQueryString, '${canonicalHeaders.join('\n')}\n', signedHeaders, payloadHash].join('\n');

    // Build string to sign - use dateString (YYYYMMDD) for credential scope
    final credentialScope = '$dateString/${config.region}/$_service/aws4_request';
    final stringToSign = ['AWS4-HMAC-SHA256', datetime, credentialScope, sha256.convert(utf8.encode(canonicalRequest)).toString()].join('\n');

    final signature = _generateSignature(stringToSign: stringToSign, dateString: dateString);

    final authHeader = 'AWS4-HMAC-SHA256 Credential=${config.key}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    return authHeader;
  }

  /// Sends a signed HTTP request to the configured S3 bucket.
  ///
  /// This method constructs the request host, canonical query string, payload
  /// hash, signed headers, and final authorization header before issuing the
  /// request through [HttpClient].
  ///
  /// Returns an [S3HttpResponse] containing the status code, body, and headers.
  ///
  /// Example:
  /// ```dart
  /// final response = await client._makeRequest(
  ///   method: 'GET',
  ///   path: '/uploads/avatar.png',
  /// );
  ///
  /// print(response.statusCode);
  /// ```
  Future<S3HttpResponse> _makeRequest({required String method, required String path, Map<String, String>? queryParams, Uint8List? body, Map<String, String>? extraHeaders}) async {
    final now = DateTime.now().toUtc();
    final datetime = HttpDate.format(now); // HTTP date format
    final dateString = _getDateString(now); // YYYYMMDD format for credential scope

    // Use virtual-hosted style for S3
    final host = '${config.bucket}.s3.${config.region}.amazonaws.com';
    final actualPath = path.startsWith('/') ? path : '/$path';

    final params = queryParams ?? {};
    final canonicalQueryString = params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').toList().join('&');

    // Calculate payload hash - for empty bodies, use the hash of an empty string
    final payloadHash = body != null ? sha256.convert(body).toString() : sha256.convert(Uint8List(0)).toString();

    final headers = <String, String>{
      'host': host,
      'x-amz-date': datetime,
      'x-amz-content-sha256': payloadHash, // Always include this header
      ...?extraHeaders,
    };

    final authHeader = _generateAuthHeader(
      method: method,
      path: actualPath,
      datetime: datetime,
      dateString: dateString,
      headers: headers,
      canonicalQueryString: canonicalQueryString,
      payloadHash: payloadHash,
    );

    headers['authorization'] = authHeader;

    final uri = Uri.https(host, actualPath, params.isEmpty ? null : params);

    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);

      // Set headers
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      if (body != null) {
        request.headers.contentLength = body.length;
        request.add(body);
      }

      final response = await request.close();
      final responseBody = await response.fold<Uint8List>(Uint8List(0), (previous, element) => Uint8List.fromList([...previous, ...element]));

      if (response.statusCode != 200 && response.statusCode != 204) {}

      return S3HttpResponse(response.statusCode, responseBody, response.headers);
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }
}


/// Raw HTTP response wrapper returned by low-level S3 requests.
///
/// Example:
/// ```dart
/// final response = S3HttpResponse(200, Uint8List(0), headers);
/// print(response.statusCode);
/// ```
base class S3HttpResponse {
  /// HTTP status code returned by S3.
  final int statusCode;

  /// Response body bytes.
  final Uint8List body;

  /// Response headers returned by S3.
  final HttpHeaders headers;

  /// Creates a raw S3 HTTP response wrapper.
  ///
  /// Example:
  /// ```dart
  /// final response = S3HttpResponse(204, Uint8List(0), headers);
  /// ```
  S3HttpResponse(this.statusCode, this.body, this.headers);
}

/// Canned ACL values for S3 object uploads.
///
/// These map to the `x-amz-acl` header values supported by S3-compatible
/// providers.
///
/// Example:
/// ```dart
/// final acl = S3Acl.publicRead;
/// print(acl.value); // public-read
/// ```
enum S3Acl {
  private('private'),
  publicRead('public-read'),
  publicReadWrite('public-read-write'),
  awsExecRead('aws-exec-read'),
  authenticatedRead('authenticated-read'),
  bucketOwnerRead('bucket-owner-read'),
  bucketOwnerFullControl('bucket-owner-full-control'),
  logDeliveryWrite('log-delivery-write');

  /// Header value sent to S3 for this canned ACL.
  final String value;

  /// Creates a canned ACL enum value.
  const S3Acl(this.value);
}

/// High-level object operations implemented on top of [S3Client].
///
/// These helpers provide convenient upload, download, existence, listing, and
/// ACL operations for S3-compatible storage.
///
/// Example:
/// ```dart
/// final ok = await client.putString(
///   'uploads/hello.txt',
///   'Hello S3',
/// );
/// ```
extension S3Operations on S3Client {
  /// Uploads raw bytes to S3 using `PUT`.
  ///
  /// Optional [contentType] and canned [acl] values are added as request
  /// headers when provided.
  ///
  /// Returns `true` when the upload succeeds with status code `200`.
  ///
  /// Example:
  /// ```dart
  /// final ok = await client.putObject(
  ///   key: 'uploads/avatar.png',
  ///   data: Uint8List.fromList([1, 2, 3]),
  ///   contentType: 'image/png',
  ///   acl: S3Acl.publicRead,
  /// );
  /// ```
  Future<bool> putObject({required String key, required Uint8List data, String? contentType, S3Acl? acl}) async {
    try {
      final headers = <String, String>{};
      if (contentType != null) {
        headers['content-type'] = contentType;
      }
      if (acl != null) {
        headers['x-amz-acl'] = acl.value;
      }

      final response = await _makeRequest(method: 'PUT', path: key, body: data, extraHeaders: headers);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Uploads a string to S3.
  ///
  /// When [contentType] is omitted, it defaults to `text/plain`.
  ///
  /// Example:
  /// ```dart
  /// final ok = await client.putString(
  ///   'logs/run.txt',
  ///   'Job completed',
  /// );
  /// ```
  Future<bool> putString(String key, String data, {String? contentType, S3Acl? acl}) async {
    return putObject(key: key, data: utf8.encode(data), contentType: contentType ?? 'text/plain', acl: acl);
  }

  /// Downloads an object as raw bytes.
  ///
  /// Returns the object body when the request succeeds with `200`, otherwise
  /// returns `null`.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await client.getObject('uploads/avatar.png');
  /// print(bytes?.length);
  /// ```
  Future<Uint8List?> getObject(String key) async {
    try {
      final response = await _makeRequest(method: 'GET', path: key);

      return response.statusCode == 200 ? response.body : null;
    } catch (e) {
      return null;
    }
  }

  /// Downloads an object and decodes it as UTF-8 text.
  ///
  /// Returns `null` when the object cannot be loaded.
  ///
  /// Example:
  /// ```dart
  /// final text = await client.getString('logs/run.txt');
  /// print(text);
  /// ```
  Future<String?> getString(String key) async {
    final data = await getObject(key);
    return data != null ? utf8.decode(data) : null;
  }

  /// Deletes an object using `DELETE`.
  ///
  /// Returns `true` when S3 responds with `204 No Content`.
  ///
  /// Example:
  /// ```dart
  /// final deleted = await client.deleteObject('uploads/old-avatar.png');
  /// print(deleted);
  /// ```
  Future<bool> deleteObject(String key) async {
    try {
      final response = await _makeRequest(method: 'DELETE', path: key);

      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// Checks whether an object exists using `HEAD`.
  ///
  /// Returns `true` when S3 responds with `200 OK`.
  ///
  /// Example:
  /// ```dart
  /// final exists = await client.objectExists('uploads/avatar.png');
  /// print(exists);
  /// ```
  Future<bool> objectExists(String key) async {
    try {
      final response = await _makeRequest(method: 'HEAD', path: key);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Lists object keys in the configured bucket.
  ///
  /// This uses the S3 ListObjectsV2 API and extracts object keys from the XML
  /// response body.
  ///
  /// Parameters:
  /// - `prefix`: Optional key prefix to filter results.
  /// - `maxKeys`: Maximum number of keys to request. Defaults to `1000`.
  ///
  /// Example:
  /// ```dart
  /// final keys = await client.listObjects(prefix: 'uploads/');
  /// print(keys);
  /// ```
  Future<List<String>> listObjects({String? prefix, int maxKeys = 1000}) async {
    try {
      final queryParams = <String, String>{'list-type': '2', 'max-keys': maxKeys.toString()};

      if (prefix != null) {
        queryParams['prefix'] = prefix;
      }

      final response = await _makeRequest(method: 'GET', path: '/', queryParams: queryParams);

      if (response.statusCode == 200) {
        final xml = utf8.decode(response.body);

        final keys = <String>[];
        final regex = RegExp(r'<Key>(.*?)</Key>');
        for (final match in regex.allMatches(xml)) {
          keys.add(match.group(1)!);
        }
        return keys;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Applies a canned ACL to an existing object.
  ///
  /// This sends a `PUT` request with the `acl` query parameter and
  /// `x-amz-acl` header.
  ///
  /// Returns `true` when S3 responds with `200 OK`.
  ///
  /// Example:
  /// ```dart
  /// final updated = await client.setObjectAcl(
  ///   'uploads/avatar.png',
  ///   S3Acl.publicRead,
  /// );
  /// print(updated);
  /// ```
  Future<bool> setObjectAcl(String key, S3Acl acl) async {
    try {
      final response = await _makeRequest(method: 'PUT', path: key, queryParams: {'acl': ''}, extraHeaders: {'x-amz-acl': acl.value});

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
