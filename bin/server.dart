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
import 'package:archery/archery/core/http/middleware/flash_messages_middleware.dart';
import 'package:archery/src/http/routes/api.dart';
import 'package:archery/src/http/routes/web.dart';
import 'package:archery/src/database/migrations/providers/sqlite_migrations_provider.dart';




Future<void> main(List<String> args) async {
  // ----------------
  // init application
  //-----------------

  final app = App();

  // parse config folder and attach to container
  final config = await AppConfig.create();
  app.container.singleton<AppConfig>(factory: (_, [_]) => config, eager: true);

  app.registerGroup("clients", [
    // uncomment when you have aws keys in config
    // uses config.get('env.aws')
    // S3ClientProvider(),
    // SesClientProvider(),
  ]);

  app.registerGroup("migrations", [
    SqliteMigrationsProvider(),
    // PgsqlMigrationsProvider(),
    // JsonFileModelsMigrationsProvider(),
  ]);

  app.registerGroup("pivots", [
    // UserRolePivotTableProvider()
  ]);

  app.registerGroup("seeders", [
    // RolesTableSeederProvider()
  ]);

  await app.boot().then((_) async {

    // NOTE - protect server after a reboot
    await Model.truncate<Session>();
    await Model.truncate<AuthSession>();

    app.container.bindInstance<List<Session>>([]);
    app.container.bindInstance<List<AuthSession>>([]);
  });

  // -------------------------------------------
  // init router, kernel and static files server
  // -------------------------------------------

  // routes
  final router = app.make<Router>();
  authRoutes(router);
  webRoutes(router);
  apiRoutes(router);

  // pass router to kernel
  final kernel = AppKernel(
      router: router,
      middleware: [
        FlashMessaging.middleware,
        VerifyCsrfToken.middleware,

      ]);

  // init port & static files server
  final port = config.get('server.port') ?? 5502;
  final staticFilesServer = app.make<StaticFilesServer>();

  // --------------
  // run the server
  // --------------

  try {
    return HttpServer.bind(InternetAddress.loopbackIPv4, port, shared: true).then((server) async {

      server.autoCompress = config.get('server.compress', true);

      server.defaultResponseHeaders.clear(); // Clear Dart's defaults if needed
      server.defaultResponseHeaders.add('X-Content-Type-Options', 'nosniff');
      server.defaultResponseHeaders.add('X-Frame-Options', 'SAMEORIGIN');
      server.defaultResponseHeaders.add('Access-Control-Allow-Origin', '*');
      server.defaultResponseHeaders.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

      print('🔥 Archery server running at http://localhost:$port');

      await for (HttpRequest request in server) {

        request.response.persistentConnection = true;

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          continue;
        }
        if (await staticFilesServer.tryServe(request)) continue;
        kernel.handle(request);
      }
    });
  } catch (e, stack) {
    App().archeryLogger.error("Error booting server", {"error": e.toString(), "stack": stack.toString()});
    await App().shutdown().then((_) => print("App has shut down from a server initialization error"));
  }
}

