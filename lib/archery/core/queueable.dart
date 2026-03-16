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

import 'dart:isolate';
import 'package:archery/archery/archery.dart';

/// Function signature for a worker isolate entry callback.
///
/// A worker receives a [SendPort] that can be used to communicate back to the
/// spawning isolate.
///
/// Example:
/// ```dart
/// void worker(SendPort sendPort) {
///   sendPort.send('ready');
/// }
/// ```
typedef IsolateWorker = void Function(SendPort);

/// Function signature for an asynchronously executed inline isolate job.
///
/// Example:
/// ```dart
/// final IsolateJob job = () async => 'done';
/// ```
typedef IsolateJob = Future<dynamic> Function();

/// Adds queue-dispatch behavior to a job-like type.
///
/// Types mixing in `Queueable` must implement [handle] and [toJson]. The mixin
/// provides:
/// - job hashing based on serialized payload
/// - queue record lookup and persistence through [QueueJob]
/// - isolate worker registration per runtime type
/// - async dispatch into a worker isolate
///
/// Example:
/// ```dart
/// class SendWelcomeEmail with Queueable {
///   final String email;
///
///   SendWelcomeEmail(this.email);
///
///   @override
///   Map<String, dynamic> toJson() => {'email': email};
///
///   @override
///   Future<dynamic> handle() async {
///     return 'sent to $email';
///   }
/// }
///
/// final result = await SendWelcomeEmail('jane@example.com').dispatch();
/// ```
mixin Queueable {
  /// Registry of worker send ports keyed by job runtime type.
  ///
  /// Each job type gets its own spawned worker isolate.
  static final Map<Type, SendPort> _workerRegistry = {};

  /// Executes the job payload.
  ///
  /// Implementations define the actual work performed when the job is handled
  /// by a worker isolate.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<dynamic> handle() async {
  ///   return 'processed';
  /// }
  /// ```
  Future<dynamic> handle();

  /// Serializes the job payload for hashing and persistence.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Map<String, dynamic> toJson() => {
  ///   'email': email,
  /// };
  /// ```
  Map<String, dynamic> toJson();

  /// Returns the persisted [QueueJob] record for this job payload, if one
  /// already exists.
  ///
  /// The payload hash is derived from `_name` plus the serialized job fields,
  /// allowing equivalent jobs to resolve to the same stored queue record.
  ///
  /// Returns `null` when no matching queue record exists.
  ///
  /// Example:
  /// ```dart
  /// final existing = await SendWelcomeEmail('jane@example.com').job;
  /// print(existing?.status.name);
  /// ```
  Future<QueueJob?> get job async {
    final modelFields = toJson();
    final jobNameField = {'_name': runtimeType.toString()};

    // this line achieves what sorting would:
    // consistence data shape for hashing
    final payloadData = {...jobNameField, ...modelFields};

    // performance hit for sorting maps vs placing _name in-front of toJson
    // so far passing equality test for the same job payloads, as hash
    // final payload = Helpers.sortRecursive(payloadData);

    final payloadString = jsonEncode(payloadData);

    final payloadBytes = utf8.encode(payloadString);

    final payloadHash = sha256.convert(payloadBytes).toString();

    return await Model.firstWhere<QueueJob>(field: "hash", value: payloadHash);
  }

  /// Dispatches this job for execution through a worker isolate.
  ///
  /// Behavior:
  /// - resolves or creates a [QueueJob] record
  /// - skips execution if the job is already complete
  /// - marks the job as processing/queued
  /// - spawns a worker isolate for the current runtime type if needed
  /// - sends the job to the worker and awaits the reply
  /// - marks the queue record complete on success
  ///
  /// On failure, the queue record is marked as failed when possible.
  ///
  /// Example:
  /// ```dart
  /// final result = await SendWelcomeEmail('jane@example.com').dispatch();
  /// print(result);
  /// ```
  Future<dynamic> dispatch() async {
    try {
      QueueJob? jobRecord = await job;

      if (jobRecord == null) {
        final payloadField = {'_name': runtimeType.toString(), ...toJson()};

        final modelData = {'status': 'created', 'payload': jsonEncode(payloadField)};

        jobRecord = QueueJob.fromJson(modelData);
        await jobRecord.save();
      }

      if (jobRecord.status == .complete) {
        return "already complete";
      }

      jobRecord.status = .processing;

      await jobRecord.save();

      final jobType = runtimeType;

      if (!_workerRegistry.containsKey(jobType)) {
        _workerRegistry[jobType] = await _spawnWorker();
        jobRecord.status = .queued;
        jobRecord.save();
      }
      final responsePort = ReceivePort();

      _workerRegistry[jobType]!.send({'job': this, 'replyTo': responsePort.sendPort});

      final result = await responsePort.first;
      responsePort.close();

      jobRecord.status = .complete;
      await jobRecord.save();

      return result;
    } catch (e, stack) {
      App().archeryLogger.error("Error in Queue Dispatch", {"origin": "mixin Queueable.dispatch", "error": e.toString(), "stack": stack.toString()});
      final jobRecord = await job;
      jobRecord?.status = .failed;
      await jobRecord?.save();
    }
  }

  /// Spawns a new worker isolate and returns its [SendPort].
  ///
  /// This is used internally to create one worker per job type.
  ///
  /// Example:
  /// ```dart
  /// final sendPort = await Queueable._spawnWorker();
  /// ```
  static Future<SendPort> _spawnWorker() async {
    final initPort = ReceivePort();
    await Isolate.spawn(_workerEntry, initPort.sendPort);
    return await initPort.first as SendPort;
  }

  /// Entry point for worker isolates used by queued jobs.
  ///
  /// The worker:
  /// - creates an incoming receive port
  /// - sends its [SendPort] back to the main isolate
  /// - listens for job messages
  /// - executes [Queueable.handle]
  /// - replies with either the result or an error payload
  ///
  /// Example:
  /// ```dart
  /// Queueable._workerEntry(mainSendPort);
  /// ```
  static void _workerEntry(SendPort mainSendPort) {
    final incoming = ReceivePort();
    mainSendPort.send(incoming.sendPort);

    incoming.listen((message) async {
      final job = message['job'] as Queueable;
      final replyTo = message['replyTo'] as SendPort;

      try {
        // 2. Execute the job inside a safety net
        final result = await job.handle();
        replyTo.send(result);
      } catch (e, stack) {
        // 3. Send the error back instead of letting the Isolate die silently
        replyTo.send({'error': e.toString(), 'stack': stack.toString()});
      }
    });
  }
}

/// Lifecycle states for persisted queue jobs.
///
/// Example:
/// ```dart
/// final status = QueueJobStatus.processing;
/// print(status.name); // processing
/// ```
enum QueueJobStatus {
  /// The queue record has been created but not yet started.
  created,

  /// The job is actively being prepared or executed.
  processing,

  /// The job has been assigned to a worker and is waiting in the queue.
  queued,

  /// The job completed successfully.
  complete,

  /// The job failed during execution.
  failed;

  /// Returns the lowercase enum name.
  ///
  /// Example:
  /// ```dart
  /// print(QueueJobStatus.complete.name); // complete
  /// ```
  String get name => toString().split('.').last.toLowerCase();

  /// Converts a stored status string into a [QueueJobStatus].
  ///
  /// Falls back to [QueueJobStatus.created] when the input is unknown.
  ///
  /// Example:
  /// ```dart
  /// final status = QueueJobStatus.fromString('failed');
  /// print(status == QueueJobStatus.failed); // true
  /// ```
  static QueueJobStatus fromString(String status) {
    return values.firstWhere((level) => level.name == status, orElse: () => .created);
  }
}


/// Persistent queue record for jobs dispatched through [Queueable].
///
/// A `QueueJob` stores the serialized payload, derived payload hash, and
/// execution status used by the queue system.
///
/// Example:
/// ```dart
/// final job = QueueJob.fromJson({
///   'status': 'created',
///   'payload': '{"_name":"SendWelcomeEmail","email":"jane@example.com"}',
/// });
///
/// print(job.status.name); // created
/// ```
class QueueJob extends Model with InstanceDatabaseOps<QueueJob> {
  /// Current queue status for the job.
  QueueJobStatus status = .created;

  /// Decoded payload originally stored for the job.
  late Map<String, dynamic> payload;

  /// Returns the SHA-256 hash of the serialized payload.
  ///
  /// This hash is used to deduplicate and look up queue jobs by payload
  /// identity.
  ///
  /// Example:
  /// ```dart
  /// print(job.hash);
  /// ```
  String get hash {
    final canonicalJson = jsonEncode((payload));
    final bytes = utf8.encode(canonicalJson);
    return sha256.convert(bytes).toString();
  }

  /// Creates a queue job model from persisted JSON.
  ///
  /// Expected keys include:
  /// - `status`
  /// - `payload`
  ///
  /// Example:
  /// ```dart
  /// final job = QueueJob.fromJson({
  ///   'status': 'queued',
  ///   'payload': '{"_name":"ReindexSearch"}',
  /// });
  /// ```
  QueueJob.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    status = QueueJobStatus.fromString(json['status']);
    payload = jsonDecode(json['payload']);
  }

  /// Serializes the queue job into a metadata-oriented JSON map.
  ///
  /// Includes the database `id`, queue status, UUID, timestamps, payload, and
  /// derived payload hash.
  ///
  /// Example:
  /// ```dart
  /// final meta = job.toMetaJson();
  /// print(meta['status']);
  /// print(meta['hash']);
  /// ```
  @override
  Map<String, dynamic> toMetaJson() {
    return {
      'id': id,
      'status': status.name,
      'uuid': uuid,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'payload': jsonEncode(payload),
      'hash': hash,
    };
  }

  /// Serializes the queue job into its standard JSON representation.
  ///
  /// Includes the UUID, timestamps, serialized payload, and derived payload
  /// hash.
  ///
  /// Example:
  /// ```dart
  /// final json = job.toJson();
  /// print(json['payload']);
  /// ```
  @override
  Map<String, dynamic> toJson() {
    return {'uuid': uuid, 'created_at': createdAt, 'updated_at': updatedAt, 'payload': jsonEncode(payload), 'hash': hash};
  }

  /// Database column definitions for persisted queue jobs.
  ///
  /// Example:
  /// ```dart
  /// print(QueueJob.columnDefinitions['status']); // TEXT NOT NULL
  /// ```
  static Map<String, String> columnDefinitions = {'status': 'TEXT NOT NULL', 'payload': 'TEXT', 'hash': 'TEXT NOT NULL'};

  /// Executes a standalone async job inside a fresh isolate and returns its
  /// result.
  ///
  /// This is useful for one-off isolate execution without defining a full
  /// `Queueable` type.
  ///
  /// Parameters:
  /// - `job`: The async function to run in the isolate.
  /// - `app`: Optional app instance, reserved for future use.
  ///
  /// Example:
  /// ```dart
  /// QueueJob.inline(() async {
  ///   return 'ran in isolate';
  /// }).then((result) => print(result));
  ///
  /// ```
  static Future<dynamic> inline(IsolateJob job, [App? app]) async {
    final receivePort = ReceivePort();

    await Isolate.spawn((SendPort sendPort) async {
      final response = await job();
      sendPort.send(response);
    }, receivePort.sendPort);

    final result = await receivePort.first;

    receivePort.close();
    return result;
  }
}
