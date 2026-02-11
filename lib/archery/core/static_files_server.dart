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

/// Serves static files from a directory with security, caching, and SPA support.
///
/// **Features:**
/// - Secure path traversal protection
/// - MIME type detection (50+ types)
/// - Cache headers (`ETag`, `Last-Modified`, `Cache-Control`)
/// - 304 Not Modified support
/// - `HEAD` request optimization
/// - SPA fallback to `index.html`
/// - Directory `index.html` auto-serve
///
/// **Usage:**
/// ```dart
/// final staticServer = StaticFilesServer(
///   root: Directory('public'),
///   maxAgeSeconds: 86400,
///   spaFallback: true,
/// );
///
/// // In middleware:
/// if (await staticServer.tryServe(request)) return;
/// ```
base class StaticFilesServer {
  /// Root directory to serve files from.
  ///
  /// Defaults to `lib/src/http/public`.
  final Directory root;

  /// Cache duration in seconds for `Cache-Control: public, max-age=...`.
  ///
  /// Default: `3600` (1 hour).
  final int maxAgeSeconds;

  /// Enables SPA mode: non-file routes return `index.html`.
  ///
  /// Useful for client-side routing (React, Vue, etc.).
  final bool spaFallback;

  /// Comprehensive MIME type mapping.
  ///
  /// Includes web, image, audio, video, fonts, and archive types.
  static const _mime = <String, String>{
    // HTML & Web App
    '.html': 'text/html; charset=utf-8',
    '.htm': 'text/html; charset=utf-8',
    '.xhtml': 'application/xhtml+xml; charset=utf-8',
    '.xml': 'application/xml; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.map': 'application/json; charset=utf-8',

    // Styles & Scripts
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.mjs': 'application/javascript; charset=utf-8',
    '.ts': 'application/typescript; charset=utf-8',
    '.wasm': 'application/wasm',

    // Text & Documents
    '.txt': 'text/plain; charset=utf-8',
    '.csv': 'text/csv; charset=utf-8',
    '.md': 'text/markdown; charset=utf-8',
    '.yaml': 'application/x-yaml; charset=utf-8',
    '.yml': 'application/x-yaml; charset=utf-8',
    '.pdf': 'application/pdf',

    // Images
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.bmp': 'image/bmp',
    '.webp': 'image/webp',
    '.tif': 'image/tiff',
    '.tiff': 'image/tiff',
    '.avif': 'image/avif',

    // Audio
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.ogg': 'audio/ogg',
    '.m4a': 'audio/mp4',
    '.flac': 'audio/flac',
    '.aac': 'audio/aac',
    '.weba': 'audio/webm',

    // Video
    '.mp4': 'video/mp4',
    '.m4v': 'video/x-m4v',
    '.webm': 'video/webm',
    '.ogv': 'video/ogg',
    '.mov': 'video/quicktime',

    // Fonts
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
    '.eot': 'application/vnd.ms-fontobject',

    // Archives & Misc
    '.zip': 'application/zip',
    '.gz': 'application/gzip',
    '.tar': 'application/x-tar',
    '.rar': 'application/vnd.rar',
    '.7z': 'application/x-7z-compressed',

    // Icons / Manifest / Web files
    '.webmanifest': 'application/manifest+json',
    '.appcache': 'text/cache-manifest; charset=utf-8',
    '.manifest': 'text/cache-manifest; charset=utf-8',
    '.rss': 'application/rss+xml; charset=utf-8',
    '.atom': 'application/atom+xml; charset=utf-8',
  };

  /// Creates a static file server.
  ///
  /// - [root]: Directory to serve (default: `lib/src/http/public`)
  /// - [maxAgeSeconds]: Cache duration (default: 1 hour)
  /// - [spaFallback]: Return `index.html` for unknown routes (default: `false`)
  StaticFilesServer({
    Directory? root,
    this.maxAgeSeconds = 3600,
    this.spaFallback = false,
  }) : root = root ?? Directory('lib/src/http/public');

  /// Attempts to serve a static file for the given [HttpRequest].
  ///
  /// **Returns `true` if file was served or 304 sent.**
  /// **Returns `false` to continue to next middleware/router.**
  ///
  /// **Security:**
  /// - Prevents path traversal (`../`)
  /// - Resolves symlinks to prevent escaping root
  /// - Only allows `GET` and `HEAD`
  Future<bool> tryServe(HttpRequest req) async {

    try {
      final method = req.method.toUpperCase();
      if (method != 'GET' && method != 'HEAD') return false;

      final rel = _sanitize(req.uri.path);
      final candidate = rel.endsWith('/') ? '${rel}index.html' : rel;

      // Try exact file
      final file = File(_join(root.path, candidate));
      if (await _serveIfExists(req, file)) return true;

      // SPA fallback
      if (spaFallback) {
        final index = File(_join(root.path, 'index.html'));
        if (await _serveIfExists(req, index)) return true;
      }

      return false;

    }catch (e) {
      return false;
    }

  }

  /// Serves [file] if it exists and is within [root].
  ///
  /// Handles:
  /// - Symlink safety
  /// - Caching headers
  /// - 304 Not Modified
  /// - `HEAD` optimization
  /// - Streaming response
  Future<bool> _serveIfExists(HttpRequest req, File file) async {
    try {
      if (!await file.exists()) return false;

      // Security: prevent path traversal via symlinks
      final rootReal = root.resolveSymbolicLinksSync();
      final fileReal = file.resolveSymbolicLinksSync();
      if (!fileReal.startsWith(rootReal)) return false;

      final stat = await file.stat();
      final etag = '"${stat.size}-${stat.modified.millisecondsSinceEpoch}"';

      final inm = req.headers.value(HttpHeaders.ifNoneMatchHeader);
      final ims = req.headers.value(HttpHeaders.ifModifiedSinceHeader);

      final res = req.response;

      // Set caching headers
      res.headers.set(
        HttpHeaders.cacheControlHeader,
        'public, max-age=$maxAgeSeconds',
      );
      res.headers.set(HttpHeaders.etagHeader, etag);
      res.headers.set(
        HttpHeaders.lastModifiedHeader,
        HttpDate.format(stat.modified),
      );
      res.headers.set(HttpHeaders.contentTypeHeader, _typeFor(file.path));

      // 304 Not Modified
      if (inm == etag ||
          (ims != null && _notModifiedSince(ims, stat.modified))) {
        res.statusCode = HttpStatus.notModified;
        await res.close();
        return true;
      }

      // HEAD: headers only
      if (req.method.toUpperCase() == 'HEAD') {
        res.statusCode = HttpStatus.ok;
        res.headers.set(HttpHeaders.contentLengthHeader, stat.size);
        await res.close();
        return true;
      }

      // GET: stream file
      res.statusCode = HttpStatus.ok;
      res.headers.set(HttpHeaders.contentLengthHeader, stat.size);
      await file.openRead().pipe(res);
      return true;
    } catch (_) {
      // Any error → let router handle
      return false;
    }
  }

  /// Checks if file has not been modified since `If-Modified-Since`.
  bool _notModifiedSince(String ims, DateTime modified) {
    try {
      final since = HttpDate.parse(ims);
      return !modified.isAfter(since);
    } catch (_) {
      return false;
    }
  }

  /// Determines MIME type from file extension.
  ///
  /// Falls back to `application/octet-stream`.
  String _typeFor(String path) {
    final i = path.lastIndexOf('.');
    final ext = (i >= 0) ? path.substring(i).toLowerCase() : '';
    return _mime[ext] ?? 'application/octet-stream';
  }

  /// Sanitizes and normalizes URL path.
  ///
  /// - Decodes `%xx`
  /// - Removes `..` and `.`
  /// - Ensures leading `/`
  /// - Prevents traversal
  ///
  /// Example: `/../../etc/passwd` → `/`
  String _sanitize(String rawPath) {
    var p = Uri.decodeComponent(rawPath);
    if (!p.startsWith('/')) p = '/$p';

    final parts = <String>[];
    for (final seg in p.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (parts.isNotEmpty) parts.removeLast();
        continue;
      }
      parts.add(seg);
    }

    return parts.isEmpty ? '/' : '/${parts.join('/')}';
  }

  /// Joins root path and relative path safely.
  String _join(String a, String b) {
    if (a.endsWith('/')) a = a.substring(0, a.length - 1);
    return '$a$b';
  }
}
