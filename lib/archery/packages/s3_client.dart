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

base class S3Config {
  final String key;
  final String secret;
  final String bucket;
  final String region;
  final String? endpoint;

  S3Config({required this.key, required this.secret, required this.bucket, this.endpoint, this.region = 'us-east-2'});

  factory S3Config.fromMap(Map<String, dynamic> map) {
    return S3Config(key: map['key'], secret: map['secret'], bucket: map['bucket'], region: map['region'] ?? 'us-east-2');
  }
}

base class S3Client {
  final S3Config config;
  final String _service = 's3';
  final bool debug;

  S3Client(this.config, {this.debug = true});

  // Todo- introduce App().fileLogger , App().consoleLogger, App().s3Logger, App().dbLogger
  // void _log(String message) {
  //   if (debug) print('[S3] $message');
  // }

  // Get date in YYYYMMDD format for credential scope
  String _getDateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _generateSignature({required String stringToSign, required String dateString /*YYYYMMDD format*/}) {
    final keyDate = Hmac(sha256, utf8.encode('AWS4${config.secret}')).convert(utf8.encode(dateString)).bytes;

    final keyRegion = Hmac(sha256, keyDate).convert(utf8.encode(config.region)).bytes;

    final keyService = Hmac(sha256, keyRegion).convert(utf8.encode(_service)).bytes;

    final keySigning = Hmac(sha256, keyService).convert(utf8.encode('aws4_request')).bytes;

    final signature = Hmac(sha256, keySigning).convert(utf8.encode(stringToSign)).toString();

    return signature;
  }

  String _generateAuthHeader({required String method, required String path, required String datetime, required String dateString, required Map<String, String> headers, required String canonicalQueryString, required String payloadHash}) {
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

    final authHeader = _generateAuthHeader(method: method, path: actualPath, datetime: datetime, dateString: dateString, headers: headers, canonicalQueryString: canonicalQueryString, payloadHash: payloadHash);

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

      if (response.statusCode != 200 && response.statusCode != 204) {
      }

      return S3HttpResponse(response.statusCode, responseBody, response.headers);
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }
}

base class S3HttpResponse {
  final int statusCode;
  final Uint8List body;
  final HttpHeaders headers;

  S3HttpResponse(this.statusCode, this.body, this.headers);
}

// S3 ACL Enum
enum S3Acl {
  private('private'),
  publicRead('public-read'),
  publicReadWrite('public-read-write'),
  awsExecRead('aws-exec-read'),
  authenticatedRead('authenticated-read'),
  bucketOwnerRead('bucket-owner-read'),
  bucketOwnerFullControl('bucket-owner-full-control'),
  logDeliveryWrite('log-delivery-write');

  final String value;

  const S3Acl(this.value);
}

extension S3Operations on S3Client {
  // Upload file (PUT)

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

  Future<bool> putString(String key, String data, {String? contentType, S3Acl? acl}) async {
    return putObject(key: key, data: utf8.encode(data), contentType: contentType ?? 'text/plain', acl: acl);
  }

  // Download file
  Future<Uint8List?> getObject(String key) async {
    try {
      final response = await _makeRequest(method: 'GET', path: key);

      return response.statusCode == 200 ? response.body : null;
    } catch (e) {
      return null;
    }
  }

  // Download as string
  Future<String?> getString(String key) async {
    final data = await getObject(key);
    return data != null ? utf8.decode(data) : null;
  }

  // Delete file (DELETE)
  Future<bool> deleteObject(String key) async {
    try {
      final response = await _makeRequest(method: 'DELETE', path: key);

      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  // Check if object exists (HEAD)
  Future<bool> objectExists(String key) async {
    try {
      final response = await _makeRequest(method: 'HEAD', path: key);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // List objects
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

  // Set object ACL after upload
  Future<bool> setObjectAcl(String key, S3Acl acl) async {
    try {
      final response = await _makeRequest(method: 'PUT', path: key, queryParams: {'acl': ''}, extraHeaders: {'x-amz-acl': acl.value});

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
