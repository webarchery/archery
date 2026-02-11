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

base class UploadedFile {
  final String filename;
  final String contentType;
  final Future<Uint8List> _cachedBytes;
  final int? _knownLength;

  UploadedFile.fromBytes({required this.filename, required Uint8List bytes, required this.contentType}) : _cachedBytes = Future.value(bytes), _knownLength = bytes.length;

  // Empty factory constructor for invalid files
  factory UploadedFile.empty() {
    return UploadedFile.fromBytes(filename: '', bytes: Uint8List(0), contentType: 'application/octet-stream');
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

  /// Check if this is an audio file
  bool get isAudio {
    final mime = contentType.toLowerCase();
    return mime.startsWith('audio/') || ['.mp3', '.wav', '.ogg', '.m4a', '.aac', '.flac'].any((ext) => filename.toLowerCase().endsWith(ext));
  }

  /// Check if this is a video file
  bool get isVideo {
    final mime = contentType.toLowerCase();
    return mime.startsWith('video/') || ['.mp4', '.webm', '.ogg', '.ogv', '.avi', '.mov', '.mkv'].any((ext) => filename.toLowerCase().endsWith(ext));
  }

  /// Check if this is an image file
  bool get isImage {
    final mime = contentType.toLowerCase();
    return mime.startsWith('image/') || ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'].any((ext) => filename.toLowerCase().endsWith(ext));
  }

  /// Get file extension
  String get extension {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Stream the file content to a StreamSink (memory efficient)
  Future<void> streamTo(StreamSink<List<int>> sink) async {
    final bytes = await _cachedBytes;
    sink.add(bytes);
  }

  /// Save the file to the specified path
  Future<File> save(String path) async {
    final file = File(path);
    final bytes = await _cachedBytes;
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Save file to specific public subdirectory
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

  /// Stream this file back to an HTTP response with proper headers
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

  Future<String?> streamToS3(HttpRequest request, {S3Acl acl = .private, bool autoName = true}) async {
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

  /// Handle HTTP range requests for media seeking
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

  /// Send complete file without range support
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

  /// Parse range header like "bytes=0-499"
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

  /// Determine proper content type based on filename and extension
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



  /// Get file info as JSON
  Future<Map<String, dynamic>> toJson() async {
    return {'filename': filename, 'contentType': contentType, 'extension': extension, 'size': await length, 'isAudio': isAudio, 'isVideo': isVideo, 'isImage': isImage};
  }

  /// Copy this file with new filename
  UploadedFile copyWith({String? filename, String? contentType}) {
    return UploadedFile.fromBytes(filename: filename ?? this.filename, bytes: _cachedBytes as Uint8List, contentType: contentType ?? this.contentType);
  }


  @override
  String toString() => 'UploadedFile(filename: $filename, type: $contentType, size: ${_knownLength ?? 'unknown'} bytes)';
}
