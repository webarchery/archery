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
/// Built-in validation rules used by request validation.
///
/// `Rule` defines simple declarative validators such as `required` and `email`,
/// and provides helpers for constructing parameterized rules like `min`,
/// `max`, and `unique`.
///
/// Example:
/// ```dart
/// final rules = [
///   Rule.required,
///   Rule.email,
///   Rule.max(255),
/// ];
/// ```
enum Rule {
  email,
  required;

  /// Creates a maximum-length validation rule.
  ///
  /// The resulting rule fails when the input length is greater than [value].
  ///
  /// Example:
  /// ```dart
  /// final rule = Rule.max(100);
  /// ```
  static MaxRule max(int value) => MaxRule(value);

  /// Creates a minimum-length validation rule.
  ///
  /// The resulting rule fails when the input length is less than [value].
  ///
  /// Example:
  /// ```dart
  /// final rule = Rule.min(8);
  /// ```
  static MinRule min(int value) => MinRule(value);

  /// Creates a uniqueness validation rule for a model column.
  ///
  /// This rule checks whether the provided value already exists in the given
  /// model column.
  ///
  /// Example:
  /// ```dart
  /// final rule = Rule.unique<User>(column: 'email');
  /// ```
  static UniqueRule unique<T extends Model>({required String column}) => UniqueRule<T>(column: column);
}

/// Validation rule that restricts a value to a maximum character length.
///
/// Example:
/// ```dart
/// final rule = MaxRule(255);
/// print(rule.limit); // 255
/// ```
class MaxRule {
  /// Maximum allowed character length.
  final int limit;

  /// Creates a max-length rule using the given limit.
  ///
  /// Example:
  /// ```dart
  /// final rule = MaxRule(50);
  /// ```
  const MaxRule(this.limit);
}
/// Validation rule that enforces a minimum character length.
///
/// Example:
/// ```dart
/// final rule = MinRule(8);
/// print(rule.limit); // 8
/// ```
class MinRule {
  /// Minimum required character length.
  final int limit;
  /// Creates a min-length rule using the given limit.
  ///
  /// Example:
  /// ```dart
  /// final rule = MinRule(3);
  /// ```
  const MinRule(this.limit);
}
/// Validation rule that ensures a field value is unique in persistent storage.
///
/// The rule queries the target model type [T] using the configured [column]
/// and passes validation only when no existing record is found.
///
/// Example:
/// ```dart
/// final rule = UniqueRule<User>(column: 'email');
/// ```
class UniqueRule<T extends Model> {
  /// The database column to check for uniqueness.
  final String column;

  /// Creates a uniqueness rule for the given model column.
  ///
  /// Example:
  /// ```dart
  /// final rule = UniqueRule<User>(column: 'username');
  /// ```
  UniqueRule({required this.column});

  /// Validates that [value] does not already exist for the configured column.
  ///
  /// Returns `true` when no existing model is found and the value is unique.
  ///
  /// Example:
  /// ```dart
  /// final isUnique = await UniqueRule<User>(column: 'email')
  ///     .validate(value: 'jane@example.com');
  /// ```
  Future<bool> validate({dynamic value}) async {
    final model = await Model.firstWhere<T>(field: column, value: value);
    return model == null;
  }
}

/// Internal validator used to evaluate request data against rule sets.
///
/// `_Validator` stores raw request data, executes validation rules per field,
/// and accumulates validation error messages.
///
/// This type is intended for framework-internal use.
///
/// Example:
/// ```dart
/// final validator = _Validator({
///   'email': 'jane@example.com',
///   'password': 'secret123',
/// });
/// ```
class _Validator {
  /// Request data being validated.
  final Map<String, dynamic> data;
  /// Validation errors grouped by field name.
  final Map<String, List<dynamic>> errors = {};

  /// Creates a validator for the provided request data.
  ///
  /// Example:
  /// ```dart
  /// final validator = _Validator({'email': 'jane@example.com'});
  /// ```
  _Validator(this.data);

  /// Validates a single [field] against the supplied list of [rules].
  ///
  /// Supported rule types include:
  /// - `Rule.required`
  /// - `Rule.email`
  /// - [MaxRule]
  /// - [MinRule]
  /// - [UniqueRule]
  ///
  /// Any validation failures are recorded in [errors].
  ///
  /// Example:
  /// ```dart
  /// await validator._validate('email', [
  ///   Rule.required,
  ///   Rule.email,
  ///   Rule.unique<User>(column: 'email'),
  /// ]);
  /// ```
  Future<void> _validate(String field, List<dynamic> rules) async {
    final value = data[field];

    for (var rule in rules) {
      if (rule == Rule.required && (value == null || value.toString().isEmpty)) {
        return _addError(field, "$field is required.");
      } else if (rule is MaxRule && (value?.toString().length ?? 0) > rule.limit) {
        _addError(field, "The $field may not be greater than ${rule.limit} characters.");
      } else if (rule is MinRule && (value?.toString().length ?? 0) < rule.limit) {
        _addError(field, "The $field may not be shorter than ${rule.limit} characters.");
      } else if (rule == Rule.email && !_isValidEmail(value)) {
        _addError(field, "The $field must be a valid email.");
      } else if (rule is UniqueRule) {
        final isUnique = await rule.validate(value: value.toString());
        if (!isUnique) {
          _addError(field, "The $field has already been taken.");
        }
      }
    }
  }

  /// Public wrapper for validating a single field.
  ///
  /// This delegates to [_validate].
  ///
  /// Example:
  /// ```dart
  /// await validator.validate('password', [
  ///   Rule.required,
  ///   Rule.min(8),
  /// ]);
  /// ```
  Future<void> validate(String field, List<dynamic> rules) async {
    return _validate(field, rules);
  }

  /// Adds a validation error message to the given [field].
  ///
  /// Example:
  /// ```dart
  /// validator._addError('email', 'The email must be valid.');
  /// ```
  void _addError(String field, String message) {
    errors.putIfAbsent(field, () => []).add(message);
  }

  /// Regular expression used to validate email addresses.
  static final _emailRegex = RegExp(r'\S+@\S+\.\S+');


  /// Returns `true` when [v] matches the internal email pattern.
  ///
  /// Example:
  /// ```dart
  /// final isValid = validator._isValidEmail('jane@example.com');
  /// ```
  bool _isValidEmail(String? v) => _emailRegex.hasMatch(v ?? "");
}

/// Adds request validation helpers to [HttpRequest].
///
/// This extension provides convenient field-level and schema-level validation
/// for incoming form data. It also preserves submitted input in session state
/// and stores validation errors for later retrieval.
///
/// Example:
/// ```dart
/// final ok = await request.validate(
///   field: 'email',
///   rules: [Rule.required, Rule.email],
/// );
/// ```
extension RequestValidation on HttpRequest {

  /// Validates a single request field using the supplied validation [rules].
  ///
  /// This method:
  /// - loads form data from the request
  /// - stores submitted values in session data for reuse
  /// - runs validation for the target field
  /// - flashes and stores validation errors in session state
  ///
  /// Returns `true` when validation succeeds; otherwise returns `false`.
  ///
  /// Example:
  /// ```dart
  /// final valid = await request.validate(
  ///   field: 'password',
  ///   rules: [Rule.required, Rule.min(8)],
  /// );
  ///
  /// if (!valid) {
  ///   return request.redirectBack();
  /// }
  /// ```
  Future<bool> validate({required String field, required List<dynamic> rules}) async {
    final data = await form().all();

    // for old('name')
    // value="{{ session.data.<name>}}"
    thisSession?.data.addAll(data);

    final validator = _Validator(data);
    await validator.validate(field, rules);

    if (validator.errors.isNotEmpty) {
      flash(key: "errors", message: "request validator errors");
      thisSession?.errors.addAll(validator.errors);
      return false;
    }

    return true;
  }

  /// Validates multiple fields using a schema of field-rule mappings.
  ///
  /// Each schema entry should contain a single field name mapped to its rule
  /// list. Empty maps are ignored, which allows controllers to build schemas
  /// conditionally.
  ///
  /// Returns `true` only when every validation in the schema succeeds.
  ///
  /// Example:
  /// ```dart
  /// final valid = await request.validateAll([
  ///   {
  ///     'name': [Rule.required, Rule.min(2), Rule.max(50)],
  ///   },
  ///   {
  ///     'email': [Rule.required, Rule.email, Rule.unique<User>(column: 'email')],
  ///   },
  ///   {
  ///     'password': [Rule.required, Rule.min(8)],
  ///   },
  /// ]);
  /// ```
  Future<bool> validateAll(List<Map<String, List<dynamic>>> schema) async {
    final tasks = schema.map((target) {
      // accounts for empty validation maps in controllers
      if (target.isEmpty) return Future.value(true);
      return validate(field: target.keys.first, rules: target.values.first);
    });

    final results = await Future.wait(tasks);
    return results.every((validation) => validation == true);
  }


}
