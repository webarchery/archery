import 'package:archery/archery/archery.dart';

class FormRequest {
  final HttpRequest _request;
  final Map<String, dynamic> _fields;
  final Map<String, UploadedFile> _files;
  bool _parsed;
  Uint8List? _bodyBuffer;
  Future<void>? _parsingFuture;

  FormRequest(this._request) : _fields = <String, dynamic>{}, _files = <String, UploadedFile>{}, _parsed = false;

  /// Access to the underlying HttpRequest
  HttpRequest get httpRequest => _request;

  /// Gets form field value from request body
  Future<dynamic> input(String key) async {
    await _ensureParsed();

    // Check query parameters first, then body fields
    // Body fields take precedence over query parameters for same key
    final queryValue = _request.uri.queryParameters[key];
    final bodyValue = _fields.containsKey(key) ? _fields[key] : null;

    return bodyValue ?? queryValue;
  }

  /// Returns all form fields merged with query parameters
  Future<Map<String, dynamic>> all() async {
    await _ensureParsed();
    return {..._request.uri.queryParameters, ..._fields};
  }

  /// Gets uploaded file for the given field name
  Future<UploadedFile?> file(String key) async {
    await _ensureParsed();
    return _files[key];
  }

  /// Returns all uploaded files
  Future<Map<String, UploadedFile>> files() async {
    await _ensureParsed();
    return Map<String, UploadedFile>.from(_files);
  }

  /// Returns only query parameters
  Map<String, String> get query => _request.uri.queryParameters;

  /// Returns only body fields
  Future<Map<String, dynamic>> body() async {
    await _ensureParsed();
    return Map<String, dynamic>.from(_fields);
  }

  /// Explicitly reads the request stream and buffers it.
  /// Called early (in Kernel) to prevent "Stream already listened" errors.
  Future<void> buffer() async {
    if (_bodyBuffer != null) return;

    try {
      final bytes = await _request.fold<BytesBuilder>(BytesBuilder(copy: false), (builder, chunk) => builder..add(chunk));
      _bodyBuffer = bytes.takeBytes();
    } catch (e) {
      // print("Error buffering request stream: $e");
      _bodyBuffer = Uint8List(0);
    }
  }

  // ----------------------------
  // Parsing Internals
  // ----------------------------
  Future<void> _ensureParsed() {
    if (_parsed) return Future.value();
    if (_parsingFuture != null) return _parsingFuture!;
    _parsingFuture = _doParse();
    return _parsingFuture!;
  }

  Future<void> _doParse() async {
    try {
      // Ensure body is buffered
      await buffer();

      final ct = _request.headers.contentType;
      final mime = ct?.mimeType ?? '';
      final bodyBytes = _bodyBuffer!;

      if (bodyBytes.isEmpty) {
        _parsed = true;
        return;
      }

      if (mime.isEmpty) {
        // print('WARNING: Body is not empty but Content-Type is missing.');
      }

      if (mime == 'application/json') {
        _parseJsonFromBytes(bodyBytes);
      } else if (mime == 'application/x-www-form-urlencoded') {
        _parseFormUrlEncodedFromBytes(bodyBytes);
      } else if (mime == 'multipart/form-data') {
        final boundary = ct?.parameters['boundary'];
        if (boundary != null && boundary.isNotEmpty) {
          await _parseMultipartFormDataFromBytes(bodyBytes, boundary);
        }
      }
    } catch (e) {
      // print('Error parsing request body: $e');
    } finally {
      _parsed = true;
    }
  }

  void _parseJsonFromBytes(Uint8List bodyBytes) {
    try {
      final body = utf8.decode(bodyBytes);
      if (body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          _fields.addAll(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e) {
      // print('JSON parsing failed: $e');
    }
  }

  void _parseFormUrlEncodedFromBytes(Uint8List bodyBytes) {
    final body = utf8.decode(bodyBytes);
    if (body.isNotEmpty) {
      _fields.addAll(Uri.splitQueryString(body));
    }
  }

  Future<void> _parseMultipartFormDataFromBytes(Uint8List bodyBytes, String boundary) async {
    final stream = Stream<Uint8List>.value(bodyBytes);
    final transformer = MimeMultipartTransformer(boundary);
    final partsStream = transformer.bind(stream);

    await for (final part in partsStream) {
      // print('DB_LOG: Found part. Headers: ${part.headers}');
      // Handle case-insensitive headers
      final dispositionKey = part.headers.keys.firstWhere((k) => k.toLowerCase() == 'content-disposition', orElse: () => '');

      if (dispositionKey.isEmpty) {
        // print('DB_LOG: No content-disposition found');
        continue;
      }

      final contentDisposition = part.headers[dispositionKey];
      // print('DB_LOG: Disposition value: $contentDisposition');

      if (contentDisposition == null) continue;

      final params = _parseContentDisposition(contentDisposition);
      final name = params['name'];
      // print('DB_LOG: Extracted name: $name');

      if (name == null) continue;

      final filename = params['filename'];

      if (filename != null && filename.isNotEmpty) {
        // File upload
        final chunks = <List<int>>[];
        await for (final chunk in part) {
          chunks.add(chunk);
        }
        final bytes = Uint8List.fromList(chunks.expand((x) => x).toList());

        if (bytes.isNotEmpty) {
          _files[name] = UploadedFile.fromBytes(filename: filename, bytes: bytes, contentType: part.headers['content-type'] ?? 'application/octet-stream');
        } else {
          _files[name] = UploadedFile.empty();
        }
      } else if (filename != null && filename.isEmpty) {
        // Empty file field
        _files[name] = UploadedFile.empty();
      } else {
        // Regular form field
        final value = await utf8.decoder.bind(part).join();
        // print('DB_LOG: Regular field value for $name: $value');
        _fields[name] = value;
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
