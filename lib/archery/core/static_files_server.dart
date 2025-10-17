import 'package:archery/archery/archery.dart';

class StaticFilesServer {
  StaticFilesServer({
    Directory? root,
    this.maxAgeSeconds = 3600,
    this.spaFallback = false,
  }) : root = root ?? Directory('lib/src/http/public');

  final Directory root;
  final int maxAgeSeconds;
  final bool spaFallback;

  static const _mime = <String, String>{
    '.html': 'text/html; charset=utf-8',
    '.htm':  'text/html; charset=utf-8',
    '.css':  'text/css; charset=utf-8',
    '.js':   'application/javascript; charset=utf-8',
    '.mjs':  'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png':  'image/png',
    '.jpg':  'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif':  'image/gif',
    '.svg':  'image/svg+xml',
    '.ico':  'image/x-icon',
    '.woff': 'font/woff',
    '.woff2':'font/woff2',
    '.map':  'application/json',
    '.txt':  'text/plain; charset=utf-8',
  };

  Future<bool> tryServe(HttpRequest req) async {
    // Only GET/HEAD are eligible
    final method = req.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD') return false;

    final rel = _sanitize(req.uri.path);
    // directory → index.html
    final candidate = rel.endsWith('/') ? '${rel}index.html' : rel;

    // Try file
    final file = File(_join(root.path, candidate));
    if (await _serveIfExists(req, file)) return true;

    // SPA fallback?
    if (spaFallback) {
      final index = File(_join(root.path, 'index.html'));
      if (await _serveIfExists(req, index)) return true;
    }

    return false;
  }


  Future<bool> _serveIfExists(HttpRequest req, File file) async {
    try {
      if (!await file.exists()) return false;

      final rootReal = root.resolveSymbolicLinksSync();
      final fileReal = file.resolveSymbolicLinksSync();
      if (!fileReal.startsWith(rootReal)) return false;

      final stat = await file.stat();
      final etag = '"${stat.size}-${stat.modified.millisecondsSinceEpoch}"';

      final inm = req.headers.value(HttpHeaders.ifNoneMatchHeader);
      final ims = req.headers.value(HttpHeaders.ifModifiedSinceHeader);

      // Headers
      final res = req.response;
      res.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=$maxAgeSeconds');
      res.headers.set(HttpHeaders.etagHeader, etag);
      res.headers.set(HttpHeaders.lastModifiedHeader, HttpDate.format(stat.modified));
      res.headers.set(HttpHeaders.contentTypeHeader, _typeFor(file.path));

      // 304 checks
      if (inm == etag ||
          (ims != null && _notModifiedSince(ims, stat.modified))) {
        res.statusCode = HttpStatus.notModified;
        await res.close();
        return true;
      }

      // HEAD short path
      if (req.method.toUpperCase() == 'HEAD') {
        res.statusCode = HttpStatus.ok;
        res.headers.set(HttpHeaders.contentLengthHeader, stat.size);
        await res.close();
        return true;
      }

      // Stream file
      res.statusCode = HttpStatus.ok;
      res.headers.set(HttpHeaders.contentLengthHeader, stat.size);
      await file.openRead().pipe(res);
      return true;
    } catch (_) {
      // fall through to router on errors
      return false;
    }
  }

  bool _notModifiedSince(String ims, DateTime modified) {
    try {
      final since = HttpDate.parse(ims);
      return !modified.isAfter(since);
    } catch (_) {
      return false;
    }
  }

  String _typeFor(String path) {
    final i = path.lastIndexOf('.');
    final ext = (i >= 0) ? path.substring(i).toLowerCase() : '';
    return _mime[ext] ?? 'application/octet-stream';
  }

  String _sanitize(String rawPath) {
    // Decode and normalize slashes
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

  String _join(String a, String b) {
    if (a.endsWith('/')) a = a.substring(0, a.length - 1);
    return '$a$b';
  }
}