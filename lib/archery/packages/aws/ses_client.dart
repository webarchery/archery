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

/// Configuration required to connect to Amazon SES or an SES-compatible
/// endpoint.
///
/// `SesConfig` stores credentials, region selection, and an optional endpoint
/// override used by [SesClient].
///
/// Example:
/// ```dart
/// final config = SesConfig(
///   key: 'AKIA...',
///   secret: 'super-secret',
///   region: 'us-east-1',
/// );
/// ```
base class SesConfig {
  /// Access key used to sign SES requests.
  final String key;

  /// Secret key used for AWS Signature Version 4 signing.
  final String secret;

  /// AWS region used in request signing and default endpoint selection.
  final String region;

  /// Optional custom SES-compatible endpoint.
  final String? endpoint;

  /// Creates an SES configuration object.
  ///
  /// Example:
  /// ```dart
  /// final config = SesConfig(
  ///   key: env['SES_KEY']!,
  ///   secret: env['SES_SECRET']!,
  ///   region: 'us-west-2',
  /// );
  /// ```
  SesConfig({required this.key, required this.secret, required this.region, this.endpoint});

  /// Creates an [SesConfig] from a map.
  ///
  /// Expected keys:
  /// - `key`
  /// - `secret`
  /// - `region` (optional, defaults to `us-east-1`)
  /// - `endpoint` (optional)
  ///
  /// Example:
  /// ```dart
  /// final config = SesConfig.fromMap({
  ///   'key': 'AKIA...',
  ///   'secret': 'super-secret',
  ///   'region': 'us-east-1',
  /// });
  /// ```
  factory SesConfig.fromMap(Map<String, dynamic> map) {
    return SesConfig(key: map['key'], secret: map['secret'], region: map['region'] ?? 'us-east-1', endpoint: map['endpoint']);
  }
}

/// Represents a file attachment to include with an outgoing email.
///
/// Example:
/// ```dart
/// final attachment = EmailAttachment(
///   name: 'report.pdf',
///   content: pdfBytes,
///   contentType: 'application/pdf',
/// );
/// ```
base class EmailAttachment {
  /// Attachment filename presented to the recipient.
  final String name;

  /// Attachment contents as raw bytes.
  final Uint8List content;

  /// MIME content type for the attachment.
  final String contentType;


  /// Creates an email attachment from in-memory bytes.
  ///
  /// When [contentType] is omitted, it defaults to
  /// `application/octet-stream`.
  ///
  /// Example:
  /// ```dart
  /// final attachment = EmailAttachment(
  ///   name: 'notes.txt',
  ///   content: Uint8List.fromList(utf8.encode('Hello')),
  ///   contentType: 'text/plain',
  /// );
  /// ```
  EmailAttachment({required this.name, required this.content, this.contentType = 'application/octet-stream'});

  /// Creates an attachment by reading the contents of a [File].
  ///
  /// When [customName] is omitted, the filename is derived from the file path.
  ///
  /// Example:
  /// ```dart
  /// final attachment = EmailAttachment.fromFile(
  ///   File('/tmp/report.pdf'),
  /// );
  /// ```
  EmailAttachment.fromFile(File file, {String? customName})
    : name = customName ?? file.path.split('/').last,
      content = file.readAsBytesSync(),
      contentType = _getContentType(file.path);

  /// Infers a MIME content type from a file path.
  ///
  /// Unknown extensions fall back to `application/octet-stream`.
  ///
  /// Example:
  /// ```dart
  /// final type = EmailAttachment._getContentType('invoice.pdf');
  /// print(type); // application/pdf
  /// ```
  static String _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'html':
        return 'text/html';
      case 'csv':
        return 'text/csv';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Represents an email address, optionally paired with a display name.
///
/// Example:
/// ```dart
/// final address = EmailAddress('jane@example.com', name: 'Jane Doe');
/// print(address.toString()); // Jane Doe <jane@example.com>
/// ```
base class EmailAddress {
  /// Raw email address.
  final String email;


  final String? name;
  /// Optional display name.

  /// Creates an email address wrapper.
  ///
  /// Example:
  /// ```dart
  /// final address = EmailAddress('support@example.com');
  /// ```
  EmailAddress(this.email, {this.name});

  /// Returns the address formatted for email headers.
  ///
  /// Produces either `Name <email@example.com>` or just `email@example.com`.
  ///
  /// Example:
  /// ```dart
  /// print(EmailAddress('jane@example.com', name: 'Jane').toString());
  /// ```
  @override
  String toString() {
    return name != null ? '$name <$email>' : email;
  }

  /// Serializes this address into a map form.
  ///
  /// Example:
  /// ```dart
  /// final map = EmailAddress('jane@example.com', name: 'Jane').toMap();
  /// print(map['EmailAddress']);
  /// ```
  Map<String, dynamic> toMap() {
    return name != null ? {'EmailAddress': email, 'Name': name} : {'EmailAddress': email};
  }
}

/// Describes an email send request for SES.
///
/// A request may contain plain-text and/or HTML bodies, optional CC/BCC
/// recipients, optional attachments, reply-to settings, and a configuration
/// set name.
///
/// Example:
/// ```dart
/// final request = SendEmailRequest(
///   from: EmailAddress('noreply@example.com', name: 'Archery'),
///   to: [EmailAddress('jane@example.com')],
///   subject: 'Welcome',
///   textBody: 'Welcome to Archery',
///   htmlBody: '<h1>Welcome to Archery</h1>',
/// );
/// ```
base class SendEmailRequest {
  /// Sender address.
  final EmailAddress from;

  /// Primary recipients.
  final List<EmailAddress> to;

  /// Optional CC recipients.
  final List<EmailAddress>? cc;

  /// Optional BCC recipients.
  final List<EmailAddress>? bcc;

  /// Email subject line.
  final String subject;

  /// Optional plain-text body.
  final String? textBody;

  /// Optional HTML body.
  final String? htmlBody;

  /// Charset used for message subject and body parts.
  final String? charset;

  /// Optional email attachments.
  final List<EmailAttachment>? attachments;

  /// Optional reply-to address.
  final String? replyTo;

  /// Optional SES configuration set name.
  final String? configurationSetName;

  /// Creates an SES email request.
  ///
  /// Example:
  /// ```dart
  /// final request = SendEmailRequest(
  ///   from: EmailAddress('noreply@example.com'),
  ///   to: [EmailAddress('user@example.com')],
  ///   subject: 'Reset Password',
  ///   textBody: 'Use the link in your dashboard.',
  /// );
  /// ```
  SendEmailRequest({
    required this.from,
    required this.to,
    this.cc,
    this.bcc,
    required this.subject,
    this.textBody,
    this.htmlBody,
    this.charset = 'UTF-8',
    this.attachments,
    this.replyTo,
    this.configurationSetName,
  });
}

/// Result returned from a successful SES send operation.
///
/// Example:
/// ```dart
/// final response = SendEmailResponse(
///   messageId: 'abc123',
///   requestId: 'req-123',
///   timestamp: DateTime.now(),
/// );
/// ```
base class SendEmailResponse {
  /// SES message identifier.
  final String messageId;

  /// AWS request identifier.
  final String requestId;

  /// Timestamp captured when the response was created.
  final DateTime timestamp;

  /// Creates an SES send response wrapper.
  ///
  /// Example:
  /// ```dart
  /// final response = SendEmailResponse(
  ///   messageId: 'message-1',
  ///   requestId: 'request-1',
  ///   timestamp: DateTime.now(),
  /// );
  /// ```
  SendEmailResponse({required this.messageId, required this.requestId, required this.timestamp});

  /// Creates a [SendEmailResponse] from an SES response map.
  ///
  /// Example:
  /// ```dart
  /// final response = SendEmailResponse.fromMap({
  ///   'MessageId': 'abc123',
  ///   'ResponseMetadata': {'RequestId': 'req-123'},
  /// });
  /// ```
  factory SendEmailResponse.fromMap(Map<String, dynamic> map) {
    return SendEmailResponse(messageId: map['MessageId'] as String, requestId: map['ResponseMetadata']['RequestId'] as String, timestamp: DateTime.now());
  }
}

/// Raw HTTP response wrapper used by the SES client internals.
///
/// Example:
/// ```dart
/// final response = SesHttpResponse(200, '<xml />', {});
/// print(response.statusCode);
/// ```
base class SesHttpResponse {
  /// HTTP status code returned by SES.
  final int statusCode;

  /// Raw response body as text.
  final String body;

  /// Response headers keyed by lowercase header name.
  final Map<String, String> headers;

  /// Creates an SES HTTP response wrapper.
  ///
  /// Example:
  /// ```dart
  /// final response = SesHttpResponse(200, 'ok', {});
  /// ```
  SesHttpResponse(this.statusCode, this.body, this.headers);
}


/// Low-level SES client that signs and sends API requests.
///
/// `SesClient` implements AWS Signature Version 4 for the SES Query API and
/// provides helpers for building standard and raw email payloads.
///
/// Example:
/// ```dart
/// final client = SesClient(
///   SesConfig(
///     key: 'AKIA...',
///     secret: 'super-secret',
///     region: 'us-east-1',
///   ),
/// );
/// ```
base class SesClient {
  /// Runtime SES configuration.
  final SesConfig config;

  /// AWS service name used during signing.
  final String _service = 'ses';

  /// Whether debug behavior is enabled.
  final bool debug;

  /// Creates an SES client.
  ///
  /// Example:
  /// ```dart
  /// final client = SesClient(config, debug: true);
  /// ```
  SesClient(this.config, {this.debug = false});

  /// Returns the date string used in AWS credential scope, formatted as
  /// `YYYYMMDD`.
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

  /// Returns the timestamp used by SES signing in ISO-8601 basic format.
  ///
  /// Example:
  /// ```dart
  /// final dt = client._getDateTimeString(DateTime.utc(2026, 3, 16, 12, 0));
  /// print(dt); // 20260316T120000Z
  /// ```
  String _getDateTimeString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$year$month${day}T$hour$minute${second}Z';
  }

  /// Generates an AWS Signature Version 4 signature.
  ///
  /// Example:
  /// ```dart
  /// final signature = client._generateSignature(
  ///   stringToSign: 'AWS4-HMAC-SHA256\n...',
  ///   dateString: '20260316',
  /// );
  /// ```
  String _generateSignature({required String stringToSign, required String dateString}) {
    final keyDate = Hmac(sha256, utf8.encode('AWS4${config.secret}')).convert(utf8.encode(dateString)).bytes;

    final keyRegion = Hmac(sha256, keyDate).convert(utf8.encode(config.region)).bytes;

    final keyService = Hmac(sha256, keyRegion).convert(utf8.encode(_service)).bytes;

    final keySigning = Hmac(sha256, keyService).convert(utf8.encode('aws4_request')).bytes;

    return Hmac(sha256, keySigning).convert(utf8.encode(stringToSign)).toString();
  }

  /// Builds the `Authorization` header for a signed SES request.
  ///
  /// Example:
  /// ```dart
  /// final auth = client._generateAuthHeader(
  ///   method: 'POST',
  ///   path: '/',
  ///   datetime: '20260316T120000Z',
  ///   dateString: '20260316',
  ///   headers: {
  ///     'host': 'email.us-east-1.amazonaws.com',
  ///     'x-amz-date': '20260316T120000Z',
  ///     'x-amz-content-sha256': 'abc123',
  ///     'content-type': 'application/x-www-form-urlencoded',
  ///     'content-length': '10',
  ///   },
  ///   canonicalQueryString: '',
  ///   payloadHash: 'abc123',
  /// );
  /// ```
  String _generateAuthHeader({
    required String method,
    required String path,
    required String datetime, // ISO-8601 basic format
    required String dateString, // YYYYMMDD format
    required Map<String, String> headers,
    required String canonicalQueryString,
    required String payloadHash,
  }) {
    // Build canonical headers
    final canonicalHeaders = headers.entries.map((e) => '${e.key.toLowerCase()}:${e.value.trim()}').toList()..sort();

    final signedHeaders = canonicalHeaders.map((h) => h.split(':')[0]).toList().join(';');

    // Build canonical request
    final canonicalRequest = [method, path, canonicalQueryString, '${canonicalHeaders.join('\n')}\n', signedHeaders, payloadHash].join('\n');

    // Build string to sign
    final credentialScope = '$dateString/${config.region}/$_service/aws4_request';
    final stringToSign = ['AWS4-HMAC-SHA256', datetime, credentialScope, sha256.convert(utf8.encode(canonicalRequest)).toString()].join('\n');

    final signature = _generateSignature(stringToSign: stringToSign, dateString: dateString);

    final authHeader = 'AWS4-HMAC-SHA256 Credential=${config.key}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    return authHeader;
  }

  /// Sends a signed HTTP request to the SES Query API.
  ///
  /// This method constructs canonical headers, signs the request, writes the
  /// form-encoded body, and returns a [SesHttpResponse].
  ///
  /// Example:
  /// ```dart
  /// final response = await client._makeRequest(
  ///   method: 'POST',
  ///   path: '/',
  ///   body: 'Action=GetSendQuota&Version=2010-12-01',
  /// );
  /// ```
  Future<SesHttpResponse> _makeRequest({required String method, required String path, required String body, Map<String, String>? queryParams}) async {
    final now = DateTime.now().toUtc();
    final datetime = _getDateTimeString(now); // ISO-8601 basic format
    final dateString = _getDateString(now); // YYYYMMDD format for credential scope

    // Use SES endpoint
    final host = config.endpoint ?? 'email.${config.region}.amazonaws.com';
    final actualPath = path.startsWith('/') ? path : '/$path';

    final params = queryParams ?? {};
    final canonicalQueryString = params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').toList().join('&');

    // Calculate payload hash
    final payloadHash = sha256.convert(utf8.encode(body)).toString();

    final headers = <String, String>{
      'host': host,
      'x-amz-date': datetime, // ISO-8601 basic format for SES
      'x-amz-content-sha256': payloadHash,
      'content-type': 'application/x-www-form-urlencoded',
      'content-length': body.length.toString(),
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

      // Write body
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(',');
      });

      if (response.statusCode != 200) {
        // todo -archeryLogger
      }

      return SesHttpResponse(response.statusCode, responseBody, responseHeaders);
    } catch (e) {
      // todo -archeryLogger
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Builds a standard SES `SendEmail` request body.
  ///
  /// This form is used when the email does not include attachments.
  ///
  /// Example:
  /// ```dart
  /// final body = client._buildEmailRequest(
  ///   SendEmailRequest(
  ///     from: EmailAddress('noreply@example.com'),
  ///     to: [EmailAddress('user@example.com')],
  ///     subject: 'Hello',
  ///     textBody: 'Welcome!',
  ///   ),
  /// );
  /// ```
  String _buildEmailRequest(SendEmailRequest request) {
    final params = <String, String>{
      'Action': 'SendEmail',
      'Version': '2010-12-01',
      'Source': request.from.toString(),
      'Message.Subject.Data': request.subject,
      'Message.Subject.Charset': request.charset ?? 'UTF-8',
    };

    // Add recipients
    params.addAll(_buildRecipients('Destination.ToAddresses.member', request.to));

    if (request.cc != null && request.cc!.isNotEmpty) {
      params.addAll(_buildRecipients('Destination.CcAddresses.member', request.cc!));
    }

    if (request.bcc != null && request.bcc!.isNotEmpty) {
      params.addAll(_buildRecipients('Destination.BccAddresses.member', request.bcc!));
    }

    // Add body
    if (request.textBody != null) {
      params['Message.Body.Text.Data'] = request.textBody!;
      params['Message.Body.Text.Charset'] = request.charset ?? 'UTF-8';
    }

    if (request.htmlBody != null) {
      params['Message.Body.Html.Data'] = request.htmlBody!;
      params['Message.Body.Html.Charset'] = request.charset ?? 'UTF-8';
    }

    // Add reply-to
    if (request.replyTo != null) {
      params['ReplyToAddresses.member.1'] = request.replyTo!;
    }

    // Add configuration set
    if (request.configurationSetName != null) {
      params['ConfigurationSetName'] = request.configurationSetName!;
    }

    // Convert to URL encoded form
    return params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
  }

  /// Builds recipient parameters for the SES Query API.
  ///
  /// Example:
  /// ```dart
  /// final params = client._buildRecipients(
  ///   'Destination.ToAddresses.member',
  ///   [EmailAddress('jane@example.com')],
  /// );
  /// ```
  Map<String, String> _buildRecipients(String prefix, List<EmailAddress> recipients) {
    final params = <String, String>{};
    for (int i = 0; i < recipients.length; i++) {
      params['$prefix.${i + 1}'] = recipients[i].toString();
    }
    return params;
  }

  /// Builds a raw MIME email message, including attachments when present.
  ///
  /// This form is used for `SendRawEmail`.
  ///
  /// Example:
  /// ```dart
  /// final raw = client._buildRawEmail(
  ///   SendEmailRequest(
  ///     from: EmailAddress('noreply@example.com'),
  ///     to: [EmailAddress('user@example.com')],
  ///     subject: 'Report',
  ///     textBody: 'See attachment',
  ///     attachments: [
  ///       EmailAttachment(
  ///         name: 'report.txt',
  ///         content: Uint8List.fromList(utf8.encode('hello')),
  ///         contentType: 'text/plain',
  ///       ),
  ///     ],
  ///   ),
  /// );
  /// ```
  String _buildRawEmail(SendEmailRequest request) {
    final boundary = '----=_NextPart_${DateTime.now().millisecondsSinceEpoch}';
    final lines = <String>[];

    // Headers
    lines.add('From: ${request.from}');
    lines.add('To: ${request.to.map((e) => e.toString()).join(', ')}');

    if (request.cc != null && request.cc!.isNotEmpty) {
      lines.add('Cc: ${request.cc!.map((e) => e.toString()).join(', ')}');
    }

    if (request.bcc != null && request.bcc!.isNotEmpty) {
      lines.add('Bcc: ${request.bcc!.map((e) => e.toString()).join(', ')}');
    }

    lines.add('Subject: ${request.subject}');
    lines.add('MIME-Version: 1.0');
    lines.add('Content-Type: multipart/mixed; boundary="$boundary"');

    if (request.replyTo != null) {
      lines.add('Reply-To: ${request.replyTo}');
    }

    lines.add(''); // Empty line before body

    // Text body
    if (request.textBody != null) {
      lines.add('--$boundary');
      lines.add('Content-Type: text/plain; charset="${request.charset}"');
      lines.add('Content-Transfer-Encoding: 7bit');
      lines.add('');
      lines.add(request.textBody!);
    }

    // HTML body
    if (request.htmlBody != null) {
      lines.add('--$boundary');
      lines.add('Content-Type: text/html; charset="${request.charset}"');
      lines.add('Content-Transfer-Encoding: 7bit');
      lines.add('');
      lines.add(request.htmlBody!);
    }

    // Attachments
    if (request.attachments != null) {
      for (final attachment in request.attachments!) {
        lines.add('--$boundary');
        lines.add('Content-Type: ${attachment.contentType}; name="${attachment.name}"');
        lines.add('Content-Disposition: attachment; filename="${attachment.name}"');
        lines.add('Content-Transfer-Encoding: base64');
        lines.add('');
        lines.add(base64.encode(attachment.content));
      }
    }

    // Closing boundary
    lines.add('--$boundary--');

    return lines.join('\r\n');
  }

  /// Builds a form-encoded SES `SendRawEmail` request body.
  ///
  /// Example:
  /// ```dart
  /// final body = client._buildRawEmailRequest(
  ///   SendEmailRequest(
  ///     from: EmailAddress('noreply@example.com'),
  ///     to: [EmailAddress('user@example.com')],
  ///     subject: 'Invoice',
  ///     attachments: [attachment],
  ///   ),
  /// );
  /// ```
  String _buildRawEmailRequest(SendEmailRequest request) {
    final rawMessage = _buildRawEmail(request);
    final params = <String, String>{
      'Action': 'SendRawEmail',
      'Version': '2010-12-01',
      'Source': request.from.toString(),
      'RawMessage.Data': base64.encode(utf8.encode(rawMessage)),
    };

    // Convert to URL encoded form
    return params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
  }

  /// Sends an email through SES.
  ///
  /// Emails without attachments use the standard `SendEmail` flow. Emails with
  /// attachments use `SendRawEmail`.
  ///
  /// Returns a [SendEmailResponse] when SES accepts the message.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.sendEmail(
  ///   SendEmailRequest(
  ///     from: EmailAddress('noreply@example.com', name: 'Archery'),
  ///     to: [EmailAddress('jane@example.com')],
  ///     subject: 'Welcome',
  ///     htmlBody: '<h1>Hello Jane</h1>',
  ///   ),
  /// );
  ///
  /// print(response.messageId);
  /// ```
  Future<SendEmailResponse> sendEmail(SendEmailRequest request) async {
    try {
      final body = request.attachments != null && request.attachments!.isNotEmpty ? _buildRawEmailRequest(request) : _buildEmailRequest(request);
      final response = await _makeRequest(method: 'POST', path: '/', body: body);

      if (response.statusCode == 200) {
        // Parse XML response
        final xml = response.body;
        final messageId = _extractFromXml(xml, 'MessageId');
        final requestId = _extractFromXml(xml, 'RequestId');

        if (messageId.isEmpty || requestId.isEmpty) {
          throw Exception('Invalid response from SES: $xml');
        }

        return SendEmailResponse(messageId: messageId, requestId: requestId, timestamp: DateTime.now());
      } else {
        final error = _extractErrorFromXml(response.body);
        throw Exception('Failed to send email (${response.statusCode}): $error');
      }
    } catch (e) {
      // todo -archeryLogger
      rethrow;
    }
  }

  /// Extracts the contents of a single XML tag from an SES response body.
  ///
  /// Example:
  /// ```dart
  /// final messageId = client._extractFromXml(
  ///   '<MessageId>abc123</MessageId>',
  ///   'MessageId',
  /// );
  /// ```
  String _extractFromXml(String xml, String tag) {
    final pattern = RegExp('<$tag>(.*?)</$tag>');
    final match = pattern.firstMatch(xml);
    return match?.group(1)?.trim() ?? '';
  }

  /// Extracts a readable SES error summary from an XML error response.
  ///
  /// Example:
  /// ```dart
  /// final error = client._extractErrorFromXml(
  ///   '<Error><Code>MessageRejected</Code><Message>Blocked</Message></Error>',
  /// );
  /// ```
  String _extractErrorFromXml(String xml) {
    final code = _extractFromXml(xml, 'Code');
    final message = _extractFromXml(xml, 'Message');
    return code.isNotEmpty && message.isNotEmpty ? '$code: $message' : 'Unknown error';
  }

  /// Retrieves the current SES send quota information.
  ///
  /// Returns a map containing:
  /// - `max24HourSend`
  /// - `maxSendRate`
  /// - `sentLast24Hours`
  ///
  /// Example:
  /// ```dart
  /// final quota = await client.getSendQuota();
  /// print(quota['max24HourSend']);
  /// ```
  Future<Map<String, dynamic>> getSendQuota() async {
    try {
      final body = 'Action=GetSendQuota&Version=2010-12-01';

      final response = await _makeRequest(method: 'POST', path: '/', body: body);

      if (response.statusCode == 200) {
        final xml = response.body;
        return {
          'max24HourSend': double.tryParse(_extractFromXml(xml, 'Max24HourSend')) ?? 0,
          'maxSendRate': double.tryParse(_extractFromXml(xml, 'MaxSendRate')) ?? 0,
          'sentLast24Hours': double.tryParse(_extractFromXml(xml, 'SentLast24Hours')) ?? 0,
        };
      } else {
        throw Exception('Failed to get send quota: ${response.statusCode}');
      }
    } catch (e) {
      // todo -archeryLogger
      rethrow;
    }
  }

  /// Convenience wrapper for sending a basic email with string addresses.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.sendSimpleEmail(
  ///   from: 'noreply@example.com',
  ///   to: ['jane@example.com'],
  ///   subject: 'Hello',
  ///   body: 'Plain text body',
  ///   htmlBody: '<p>Plain text body</p>',
  /// );
  /// ```
  Future<SendEmailResponse> sendSimpleEmail({
    required String from,
    required List<String> to,
    required String subject,
    String? body,
    String? htmlBody,
    List<String>? cc,
    List<String>? bcc,
  }) async {
    final emailRequest = SendEmailRequest(
      from: EmailAddress(from),
      to: to.map((e) => EmailAddress(e)).toList(),
      cc: cc?.map((e) => EmailAddress(e)).toList(),
      bcc: bcc?.map((e) => EmailAddress(e)).toList(),
      subject: subject,
      textBody: body,
      htmlBody: htmlBody,
    );

    return sendEmail(emailRequest);
  }

  /// Tests connectivity to SES by attempting to fetch send quota data.
  ///
  /// Returns `true` when the quota request succeeds.
  ///
  /// Example:
  /// ```dart
  /// final ok = await client.testConnection();
  /// print(ok);
  /// ```
  Future<bool> testConnection() async {
    try {
      final quota = await getSendQuota();
      return quota.isNotEmpty;
    } catch (e) {
      // todo -archeryLogger
      return false;
    }
  }
}
