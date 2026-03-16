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

/// Represents an uploaded file parsed from an incoming HTTP request.
///
/// `UploadedFile` provides convenient access to file metadata, raw bytes,
/// string content, type inspection helpers, disk persistence methods, HTTP
/// response streaming, and S3 upload support.
///
/// Instances are typically created internally while parsing multipart form
/// data, but they can also be constructed directly from bytes.
///
/// Example:
/// ```dart
/// final file = UploadedFile.fromBytes(
///   filename: 'avatar.png',
///   bytes: Uint8List.fromList([1, 2, 3]),
///   contentType: 'image/png',
/// );
///
/// print(file.filename); // avatar.png
/// print(file.isImage); // true
/// ```
base class UploadedFile {
  /// Original filename supplied by the client.
  final String filename;

  /// MIME content type associated with the uploaded file.
  final String contentType;

  /// Cached file bytes stored as a future so callers can await access
  /// consistently.
  final Future<Uint8List> _cachedBytes;

  /// Known byte length, when already available at construction time.
  final int? _knownLength;

  /// Creates an uploaded file from an in-memory byte buffer.
  ///
  /// This constructor caches the provided bytes immediately and stores their
  /// length for later access.
  ///
  /// Example:
  /// ```dart
  /// final file = UploadedFile.fromBytes(
  ///   filename: 'song.mp3',
  ///   bytes: Uint8List.fromList([0, 1, 2, 3]),
  ///   contentType: 'audio/mpeg',
  /// );
  /// ```
  UploadedFile.fromBytes({required this.filename, required Uint8List bytes, required this.contentType}) : _cachedBytes = Future.value(bytes), _knownLength = bytes.length;

  /// Creates an empty placeholder file.
  ///
  /// This is used internally to represent an invalid or empty upload field.
  ///
  /// Example:
  /// ```dart
  /// final file = UploadedFile.empty();
  /// print(file.isValid); // false
  /// ```
  factory UploadedFile.empty() {
    return UploadedFile.fromBytes(filename: '', bytes: Uint8List(0), contentType: 'application/octet-stream');
  }

  /// Returns `true` when the file has a non-empty filename.
  ///
  /// This is commonly used to distinguish real uploads from empty placeholders.
  ///
  /// Example:
  /// ```dart
  /// if (file.isValid) {
  ///   print('Uploaded file is usable');
  /// }
  /// ```
  bool get isValid => filename.isNotEmpty;

  /// Returns the file contents as raw bytes.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await file.bytes;
  /// print(bytes.length);
  /// ```
  Future<Uint8List> get bytes async => await _cachedBytes;

  /// Returns the file contents decoded as UTF-8 text.
  ///
  /// This is most useful for text-based uploads.
  ///
  /// Example:
  /// ```dart
  /// final textFile = UploadedFile.fromBytes(
  ///   filename: 'notes.txt',
  ///   bytes: Uint8List.fromList(utf8.encode('Hello world')),
  ///   contentType: 'text/plain',
  /// );
  ///
  /// print(await textFile.string); // Hello world
  /// ```
  Future<String> get string async => utf8.decode(await _cachedBytes);

  /// Returns the byte length of the file.
  ///
  /// Example:
  /// ```dart
  /// final size = await file.length;
  /// print(size);
  /// ```
  Future<int> get length async => _knownLength ?? (await _cachedBytes).length;

  /// Returns `true` when the file length is already known without recomputing
  /// it.
  ///
  /// Example:
  /// ```dart
  /// print(file.isLengthKnown);
  /// ```
  bool get isLengthKnown => _knownLength != null;

  /// Returns `true` when the file appears to be an audio file.
  ///
  /// Detection is based on MIME type and common filename extensions.
  ///
  /// Example:
  /// ```dart
  /// if (file.isAudio) {
  ///   print('This upload is audio');
  /// }
  /// ```
  bool get isAudio {
    final mime = contentType.toLowerCase();
    return mime.startsWith('audio/') || ['.mp3', '.wav', '.ogg', '.m4a', '.aac', '.flac'].any((ext) => filename.toLowerCase().endsWith(ext));
  }

  /// Returns `true` when the file appears to be a video file.
  ///
  /// Detection is based on MIME type and common filename extensions.
  ///
  /// Example:
  /// ```dart
  /// if (file.isVideo) {
  ///   print('This upload is video');
  /// }
  /// ```
  bool get isVideo {
    final mime = contentType.toLowerCase();
    return mime.startsWith('video/') || ['.mp4', '.webm', '.ogg', '.ogv', '.avi', '.mov', '.mkv'].any((ext) => filename.toLowerCase().endsWith(ext));
  }

  /// Returns `true` when the file appears to be an image file.
  ///
  /// Detection is based on MIME type and common filename extensions.
  ///
  /// Example:
  /// ```dart
  /// if (file.isImage) {
  ///   print('Generate a thumbnail');
  /// }
  /// ```
  bool get isImage {
    final mime = contentType.toLowerCase();
    return mime.startsWith('image/') || ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'].any((ext) => filename.toLowerCase().endsWith(ext));
  }

  /// Returns the lowercase file extension without a leading dot.
  ///
  /// Example:
  /// ```dart
  /// print(file.extension); // png
  /// ```
  String get extension {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Streams the file bytes into a [StreamSink].
  ///
  /// This is useful when piping the upload into another stream destination.
  ///
  /// Example:
  /// ```dart
  /// final controller = StreamController<List<int>>();
  /// await file.streamTo(controller.sink);
  /// await controller.close();
  /// ```
  Future<void> streamTo(StreamSink<List<int>> sink) async {
    final bytes = await _cachedBytes;
    sink.add(bytes);
  }

  /// Saves the file to the provided filesystem [path].
  ///
  /// Returns the written [File].
  ///
  /// Example:
  /// ```dart
  /// final saved = await file.save('/tmp/avatar.png');
  /// print(saved.path);
  /// ```
  Future<File> save(String path) async {
    final file = File(path);
    final bytes = await _cachedBytes;
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Saves the file into a subdirectory of the public storage path.
  ///
  /// When [autoName] is `true`, a UUID-based filename is generated while
  /// preserving the original extension when possible.
  ///
  /// Returns the written [File].
  ///
  /// Example:
  /// ```dart
  /// final saved = await file.saveToPublicDir('avatars');
  /// print(saved.path);
  /// ```
  Future<File> saveToPublicDir(String subDir, {bool autoName = true}) async {
    final String fileName;

    if (autoName) {
      final ext = extension.isNotEmpty ? '.$extension' : '';
      final uuid = Uuid().v4();
      fileName = '$uuid$ext';
    } else {
      fileName = filename;
    }

    final file = File('lib/src/http/public/$subDir/$fileName');

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final bytes = await _cachedBytes;
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Saves the file into a subdirectory of the private storage path.
  ///
  /// When [autoName] is `true`, a UUID-based filename is generated while
  /// preserving the original extension when possible.
  ///
  /// Returns the written [File].
  ///
  /// Example:
  /// ```dart
  /// final saved = await file.saveToPrivateDir('documents');
  /// print(saved.path);
  /// ```
  Future<File> saveToPrivateDir(String subDir, {bool autoName = true}) async {
    final String fileName;

    if (autoName) {
      final ext = extension.isNotEmpty ? '.$extension' : '';
      final uuid = Uuid().v4();
      fileName = '$uuid$ext';
    } else {
      fileName = filename;
    }

    final file = File('lib/src/storage/private/$subDir/$fileName');

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final bytes = await _cachedBytes;
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Streams this file to the current HTTP response.
  ///
  /// Range requests are supported by default, which is especially useful for
  /// browser media playback and seeking.
  ///
  /// Parameters:
  /// - `request`: The active request whose response will receive the file.
  /// - `handleRange`: Whether to honor `Range` headers. Defaults to `true`.
  ///
  /// Example:
  /// ```dart
  /// final file = await request.form().file('video');
  /// if (file != null) {
  ///   await file.streamToResponse(request);
  /// }
  /// ```
  Future<void> streamToResponse(HttpRequest request, {bool handleRange = true}) async {
    final totalLength = await length;
    final bytes = await _cachedBytes;

    // Check for range requests (important for media playback)
    final rangeHeader = request.headers[HttpHeaders.rangeHeader];

    if (handleRange && rangeHeader != null && rangeHeader.isNotEmpty) {
      await _handleRangeRequest(request, bytes, totalLength, rangeHeader.first);
    } else {
      await _sendFullFile(request, bytes, totalLength);
    }
  }

  /// Uploads the file to S3 and returns the stored object key.
  ///
  /// The generated key includes the current application ID and stores uploads
  /// under the framework upload prefix.
  ///
  /// When [autoName] is `true`, a UUID-based filename is generated while
  /// preserving the extension when possible.
  ///
  /// Returns the S3 object key on success, or `null` on failure.
  ///
  /// Example:
  /// ```dart
  /// final key = await file.streamToS3(acl: S3Acl.private);
  /// print(key);
  /// ```
  Future<String?> streamToS3({S3Acl acl = .private, bool autoName = true}) async {
    final s3Client = App().make<S3Client>();
    final config = App().make<AppConfig>();
    final uuid = App().make<Uuid>();

    final String fileName;

    if (autoName) {
      final ext = extension.isNotEmpty ? '.$extension' : '';
      final uuid = Uuid().v4();
      fileName = '$uuid$ext';
    } else {
      fileName = filename;
    }

    final String key = "archery/web/app-${config.get('app.id', uuid.v4())}/storage/uploads/$fileName";

    if (await s3Client.putObject(
      key: key,
      data: await _cachedBytes, // ← Stream directly to S3
      acl: acl,
      contentType: contentType,
    )) {
      return key;
    }
    return null;
  }

  /// Handles an HTTP byte-range request for this file.
  ///
  /// If the range is valid, the response is sent as `206 Partial Content`.
  /// Invalid ranges produce `416 Requested Range Not Satisfiable`.
  ///
  /// This method is used internally by [streamToResponse].
  ///
  /// Example:
  /// ```dart
  /// await file._handleRangeRequest(
  ///   request,
  ///   await file.bytes,
  ///   await file.length,
  ///   'bytes=0-499',
  /// );
  /// ```
  Future<void> _handleRangeRequest(HttpRequest request, Uint8List bytes, int totalLength, String rangeHeader) async {
    final response = request.response;

    try {
      final range = _parseRangeHeader(rangeHeader, totalLength);
      if (range == null) {
        response
          ..statusCode = HttpStatus.requestedRangeNotSatisfiable
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$totalLength')
          ..close();
        return;
      }

      final (start, end) = range;
      final chunkLength = end - start + 1;
      final chunk = bytes.sublist(start, end + 1);

      // Set headers for partial content
      response.headers
        ..contentType = _determineContentType()
        ..set(HttpHeaders.contentLengthHeader, chunkLength.toString())
        ..set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalLength')
        ..set('Accept-Ranges', 'bytes');

      // Send 206 Partial Content
      response.statusCode = HttpStatus.partialContent;
      response.add(chunk);
      await response.close();
    } catch (e) {
      // Fall back to full file
      await _sendFullFile(request, bytes, totalLength);
    }
  }

  /// Sends the complete file without range handling.
  ///
  /// This method applies content type, length, caching headers, and media CORS
  /// headers when appropriate.
  ///
  /// Example:
  /// ```dart
  /// await file._sendFullFile(request, await file.bytes, await file.length);
  /// ```
  Future<void> _sendFullFile(HttpRequest request, Uint8List bytes, int totalLength) async {
    final response = request.response;

    response.headers
      ..contentType = _determineContentType()
      ..set(HttpHeaders.contentLengthHeader, totalLength.toString())
      ..set('Accept-Ranges', 'bytes')
      ..set('Cache-Control', 'public, max-age=31536000');

    // Add CORS headers for web media
    if (isAudio || isVideo) {
      response.headers.set('Access-Control-Allow-Origin', '*');
    }

    response.statusCode = HttpStatus.ok;
    response.add(bytes);
    await response.close();
  }

  /// Parses a range header such as `bytes=0-499`.
  ///
  /// Returns a `(start, end)` record when the range is valid, otherwise `null`.
  ///
  /// Example:
  /// ```dart
  /// final range = file._parseRangeHeader('bytes=0-499', 1000);
  /// print(range); // (0, 499)
  /// ```
  (int, int)? _parseRangeHeader(String rangeHeader, int totalLength) {
    try {
      // Format: "bytes=start-end"
      final range = rangeHeader.substring(6); // Remove "bytes="
      final parts = range.split('-');

      if (parts.length != 2) return null;

      int start = int.parse(parts[0]);
      int end = parts[1].isEmpty ? totalLength - 1 : int.parse(parts[1]);

      // Validate range
      if (start < 0 || end >= totalLength || start > end) {
        return null;
      }

      return (start, end);
    } catch (e) {
      return null;
    }
  }

  /// Determines the best [ContentType] for this file.
  ///
  /// Known media and image extensions are mapped to browser-friendly MIME
  /// types. Unknown extensions fall back to the stored [contentType].
  ///
  /// Example:
  /// ```dart
  /// final type = file._determineContentType();
  /// print(type);
  /// ```
  ContentType _determineContentType() {
    final ext = extension;

    // EXACT browser-recognized MIME types
    switch (ext) {
      // Audio
      case 'mp3':
        return ContentType.parse('audio/mpeg');
      case 'wav':
        return ContentType.parse('audio/wav');
      case 'ogg':
        return ContentType.parse('audio/ogg');
      case 'm4a':
        return ContentType.parse('audio/mp4');
      case 'aac':
        return ContentType.parse('audio/aac');
      case 'flac':
        return ContentType.parse('audio/flac');
      case 'weba':
        return ContentType.parse('audio/webm');

      // Video
      case 'mp4':
        return ContentType.parse('video/mp4');
      case 'm4v':
        return ContentType.parse('video/mp4');
      case 'webm':
        return ContentType.parse('video/webm');
      case 'ogv':
        return ContentType.parse('video/ogg');
      case 'avi':
        return ContentType.parse('video/x-msvideo');
      case 'mov':
        return ContentType.parse('video/quicktime');
      case 'mkv':
        return ContentType.parse('video/x-matroska');
      case 'wmv':
        return ContentType.parse('video/x-ms-wmv');
      case 'flv':
        return ContentType.parse('video/x-flv');

      // Images
      case 'jpg':
      case 'jpeg':
        return ContentType.parse('image/jpeg');
      case 'png':
        return ContentType.parse('image/png');
      case 'gif':
        return ContentType.parse('image/gif');
      case 'webp':
        return ContentType.parse('image/webp');
      case 'svg':
        return ContentType.parse('image/svg+xml');
      case 'bmp':
        return ContentType.parse('image/bmp');
      case 'ico':
        return ContentType.parse('image/x-icon');

      default:
        // Fallback with charset for text-like files
        if (contentType.startsWith('text/')) {
          return ContentType.parse('$contentType; charset=utf-8');
        }
        return ContentType.parse(contentType);
    }
  }

  /// Returns file metadata as a JSON-compatible map.
  ///
  /// Included keys:
  /// - `filename`
  /// - `contentType`
  /// - `extension`
  /// - `size`
  /// - `isAudio`
  /// - `isVideo`
  /// - `isImage`
  ///
  /// Example:
  /// ```dart
  /// final json = await file.toJson();
  /// print(json['filename']);
  /// ```
  Future<Map<String, dynamic>> toJson() async {
    return {'filename': filename, 'contentType': contentType, 'extension': extension, 'size': await length, 'isAudio': isAudio, 'isVideo': isVideo, 'isImage': isImage};
  }

  /// Returns a copy of this file with updated metadata.
  ///
  /// This preserves the same underlying file contents while allowing the
  /// filename and/or content type to be overridden.
  ///
  /// Because the source bytes are stored asynchronously, this method is async.
  ///
  /// Example:
  /// ```dart
  /// final renamed = await file.copyWith(filename: 'cover.png');
  /// print(renamed.filename); // cover.png
  /// ```
  Future<UploadedFile> copyWith({String? filename, String? contentType}) async {
    return UploadedFile.fromBytes(filename: filename ?? this.filename, bytes: await _cachedBytes, contentType: contentType ?? this.contentType);
  }

  /// Returns a developer-friendly string representation of the file.
  ///
  /// Example:
  /// ```dart
  /// print(file);
  /// ```
  @override
  String toString() => 'UploadedFile(filename: $filename, type: $contentType, size: ${_knownLength ?? 'unknown'} bytes)';
}
