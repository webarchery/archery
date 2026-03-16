import 'package:archery/archery/archery.dart';

/// Queueable job that sends a simple email through SES.
///
/// `SimpleEmailJob` is intended for lightweight email delivery where only a
/// sender, recipient list, subject, and plain-text message body are required.
///
/// The job serializes cleanly for queue persistence and executes its work by
/// constructing an SES client at handle time.
///
/// Example:
/// ```dart
/// final result = await SimpleEmailJob(
///   from: 'noreply@app.dev',
///   to: ['jane@example.com'],
///   subject: 'Welcome',
///   message: 'Thanks for signing up.',
/// ).dispatch();
/// ```
class SimpleEmailJob with Queueable {
  /// Sender email address.
  late final String from;

  /// Recipient email addresses.
  late final List<String> to;

  /// Email subject line.
  late final String subject;

  /// Plain-text email body.
  late final String message;

  /// Creates a simple queued email job.
  ///
  /// Example:
  /// ```dart
  /// final job = SimpleEmailJob(
  ///   from: 'noreply@app.dev',
  ///   to: ['team@app.dev'],
  ///   subject: 'Build finished',
  ///   message: 'The nightly build completed successfully.',
  /// );
  /// ```
  SimpleEmailJob({
    required this.from,
    required this.to,
    required this.subject,
    required this.message
  });

  /// Serializes the job payload for queue persistence and hashing.
  ///
  /// Example:
  /// ```dart
  /// final payload = SimpleEmailJob(
  ///   from: 'noreply@app.dev',
  ///   to: ['jane@example.com'],
  ///   subject: 'Hello',
  ///   message: 'Welcome aboard.',
  /// ).toJson();
  ///
  /// print(payload['subject']);
  /// ```
  @override
  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'subject': subject,
      'message': message
    };
  }

  /// Executes the email send operation in an isolate
  ///
  /// This method:
  /// - loads app configuration
  /// - builds an [SesConfig] from `env.aws`
  /// - creates an [SesClient]
  /// - sends the email using `sendSimpleEmail`
  /// - returns a small result payload containing SES response metadata
  ///
  /// Example:
  /// ```dart
  /// final result = await SimpleEmailJob(
  ///   from: 'noreply@app.dev',
  ///   to: ['jane@example.com'],
  ///   subject: 'Welcome',
  ///   message: 'Thanks for joining.',
  /// ).handle();
  ///
  /// print(result['message_id']);
  /// ```

  @override
  Future<dynamic> handle() async {

    final config = await AppConfig.create();

    final sesConfig = SesConfig.fromMap(config.get('env.aws'));
    final sesClient = SesClient(sesConfig, debug: true);

    final response = await sesClient.sendSimpleEmail(
      from: from,
      to: to,
      subject: subject,
      body: message,
    );

    return {
      "request_id": response.requestId,
      "message_id": response.messageId,
      "timestamp": response.timestamp
    };
  }
}
