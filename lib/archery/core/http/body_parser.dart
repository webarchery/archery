
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

/// Caches we attach to each HttpRequest without altering the class.
final _parsedBody = Expando<bool>('archery.request.parsed');
final _fieldBag = Expando<Map<String, dynamic>>('archery.request.fields');
final _fileBag = Expando<Map<String, UploadedFile>>('archery.request.files');

/// Represents an uploaded file from multipart form data
class UploadedFile {
  final String filename;
  final String contentType;
  final Future<Uint8List> _cachedBytes;
  final int? _knownLength;

  UploadedFile.fromBytes({
    required this.filename,
    required Uint8List bytes,
    required this.contentType,
  })  : _cachedBytes = Future.value(bytes),
        _knownLength = bytes.length;

  // empty factory constructor for invalid files
  factory UploadedFile.empty() {
    return UploadedFile.fromBytes(
      filename: '',
      bytes: Uint8List(0),
      contentType: 'application/octet-stream',
    );
  }

  // Add validation property
  bool get isValid => filename.isNotEmpty;


  /// Get the file content as bytes
  Future<Uint8List> get bytes async => await _cachedBytes;

  /// Get the file content as string
  Future<String> get string async => utf8.decode(await _cachedBytes);

  /// Get the length
  Future<int> get length async => _knownLength ?? (await _cachedBytes).length;

  /// Check if length is known without calculating it
  bool get isLengthKnown => _knownLength != null;

  /// Stream the file content to a StreamSink (memory efficient)
  Future<void> streamTo(StreamSink<List<int>> sink) async {
    final bytes = await _cachedBytes;
    sink.add(bytes);
    // Note: No flush() - StreamSink doesn't have flush capability
    // Caller is responsible for flushing/closing the sink
  }

  /// Save the file to the specified path
  /// you must know how dart projects relate to your root folder to know exactly where to save your images
  /// use Directory("lib/src/") to hook into your codebase
  Future<File> save(String path) async {
    final file = File(path);
    final bytes = await _cachedBytes;
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<File> savePublic({bool autoName = true}) async {

    if(autoName) {
      final ext = filename.split(".").last;

      final uuid = Uuid().v4();

      final newFileName = "$uuid.$ext";
      final file = File("lib/src/http/public/img/$newFileName");




      if(!await file.exists()) await file.create(recursive: true);

      final bytes = await _cachedBytes;
      await file.writeAsBytes(bytes);
      return file;

    } else {

      final file = File("lib/src/http/public/img/$filename");


      if(!await file.exists()) await file.create(recursive: true);

      final bytes = await _cachedBytes;
      await file.writeAsBytes(bytes);
      return file;
    }


  }



  @override
  String toString() => 'UploadedFile(filename: $filename, type: $contentType, lengthKnown: $isLengthKnown)';
}

extension ArcheryRequestInput on HttpRequest {
  /// Gets form field value from request body for x-www-form-urlencoded, JSON, or multipart form data.
  /// Also checks URL query parameters. Returns null if key not found. Only returns non-file fields.
  /// Priority: Body parameters > Query parameters (body overrides query for same key)
  Future<dynamic> input(String key) async {
    await _ensureParsed();
    final fields = _fieldBag[this];

    // Check query parameters first, then body fields
    // Body fields take precedence over query parameters for same key
    final queryValue = uri.queryParameters[key];
    final bodyValue = fields != null && fields.containsKey(key) ? fields[key] : null;

    // Return body value if exists, otherwise query value
    return bodyValue ?? queryValue;
  }

  /// Returns all form fields (non-file) from request body merged with query parameters
  /// Body fields take precedence over query parameters for same keys
  Future<Map<String, dynamic>> all() async {
    await _ensureParsed();
    final bodyFields = _fieldBag[this] ?? {};

    // Merge query parameters with body fields
    // Body fields override query parameters for same keys
    return {...uri.queryParameters, ...bodyFields};
  }

  /// Gets uploaded file for the given field name from multipart form data
  /// Returns null if key not found or request is not multipart
  /// Note: Files are only from multipart form data body, not from query parameters
  Future<UploadedFile?> file(String key) async {
    await _ensureParsed();
    final files = _fileBag[this];
    return files != null && files.containsKey(key) ? files[key] : null;
  }

  /// Returns all uploaded files from multipart form data
  Future<Map<String, UploadedFile>> files() async {
    await _ensureParsed();
    return Map<String, UploadedFile>.from(_fileBag[this] ?? {});
  }

  /// Returns only query parameters (without body fields)
  Map<String, String> get query => Map<String, String>.from(uri.queryParameters);

  /// Returns only body fields (without query parameters)
  Future<Map<String, dynamic>> body() async {
    await _ensureParsed();
    return Map<String, dynamic>.from(_fieldBag[this] ?? {});
  }

  // ----------------------------
  // Internals
  // ----------------------------

  Future<void> _ensureParsed() async {
    if (_parsedBody[this] == true) return;


    // Initialize bags
    _fieldBag[this] = <String, dynamic>{};
    _fileBag[this] = <String, UploadedFile>{};

    final ct = headers.contentType;
    final mime = ct?.mimeType ?? '';

    if (mime == 'application/json') {
      await _parseJson();
    } else if (mime == 'application/x-www-form-urlencoded') {
      await _parseFormUrlEncoded();
    } else if (mime == 'multipart/form-data') {
      await _parseMultipartFormData();
    } else {
      // Unsupported/empty: do nothing; keep maps empty
    }

    _parsedBody[this] = true;
  }

  Future<void> _parseJson() async {
    final body = await utf8.decoder.bind(this).join();
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          _fieldBag[this] = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        // JSON parsing failed, leave fields empty
      }
    }
  }

  Future<void> _parseFormUrlEncoded() async {
    final body = await utf8.decoder.bind(this).join();
    if (body.isNotEmpty) {
      _fieldBag[this] = Uri.splitQueryString(body);
    }
  }

  Future<void> _parseMultipartFormData() async {
    final boundary = headers.contentType?.parameters['boundary'];
    if (boundary == null) return;

    final transformer = MimeMultipartTransformer(boundary);
    final partsStream = transformer.bind(this);

    await for (final part in partsStream) {
      final contentDisposition = part.headers['content-disposition'];
      if (contentDisposition == null) continue;

      final params = _parseContentDisposition(contentDisposition);
      final name = params['name'];
      if (name == null) continue;

      final filename = params['filename'];

      if (filename != null && filename.isNotEmpty) {
        // This is a file upload - read into memory immediately
        final chunks = <List<int>>[];
        await for (final chunk in part) {
          chunks.add(chunk);
        }
        final bytes = Uint8List.fromList(chunks.expand((x) => x).toList());

        if (bytes.isNotEmpty) {
          _fileBag[this]![name] = UploadedFile.fromBytes(
            filename: filename,
            bytes: bytes,
            contentType: part.headers['content-type'] ?? 'application/octet-stream',
          );
        } else {
          // Empty file - store as empty
          _fileBag[this]![name] = UploadedFile.empty();
        }
      }

      else if (filename != null && filename.isEmpty) {
        // File field present but no file selected - store as empty
        _fileBag[this]![name] = UploadedFile.empty();
      }

      else {
        // This is a regular form field - read into memory (small size)
        final value = await utf8.decoder.bind(part).join();
        _fieldBag[this]![name] = value;
      }
    }
  }

  Map<String, String> _parseContentDisposition(String contentDisposition) {
    final params = <String, String>{};
    final parts = contentDisposition.split(';');

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('=')) {
        final keyValue = trimmed.split('=');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          var value = keyValue[1].trim();
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          }
          params[key] = value;
        }
      }
    }

    return params;
  }
}


