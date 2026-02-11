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

library;

import 'package:postgres/postgres.dart'  ;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'dart:io';
export 'dart:convert';
export 'dart:math';
export 'dart:async';

export 'package:uuid/uuid.dart';
export 'package:crypto/crypto.dart';
export 'package:collection/collection.dart';
export 'package:sqflite_common_ffi/sqflite_ffi.dart';
export 'package:intl/intl.dart';
export 'dart:typed_data';
export 'package:mime/mime.dart';


//**********************************
export './core/container.dart'
    show ServiceContainer, Container, ServiceContainerException;

//***********************************
export './core/provider.dart' show Provider, ProviderException;
//***********************************
export './core/application.dart' show ContainerOperations, AppStatus, App, GetConfig, GetLoggers, Boot, CurrentRequest;

//***********************************
export './core/config.dart' show ConfigRepository, AppConfig;

//***********************************
export './core/kernel.dart';

//***********************************
export './core/template_engine.dart';

//***********************************
export './core/logger.dart';

//***********************************
export './core/static_files_server.dart';

//***********************************

export '../src/database/models/user.dart';

//***********************************
export './core/orm/hasher.dart';
//***********************************

export './core/orm/model.dart';
//***********************************

export './core/orm/json_file_model.dart';
//***********************************

export './core/orm/s3_json_file_model.dart';
//***********************************

export './core/orm/sqlite_model.dart';

//***********************************

export './core/orm/postgres_model.dart';

//***********************************
export 'core/http/http.dart';
export 'core/http/middleware/csrf_middleware.dart';

export 'core/auth/auth_session.dart';


//*************************************
export './packages/s3_client.dart';


typedef SQLiteDatabase = Database;
typedef PostgresDatabase = Connection;
