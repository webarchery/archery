import 'package:archery/archery/archery.dart';
import 'package:archery/src/http/controllers/blog/blog_pages_controller.dart';

import '../../apps/todos.dart';

void webRoutes(Router router) {
  todoRoutes(router);

  router.post('/debug-form', (request) async {
    final responseData = <String, dynamic>{};

    try {
      responseData['headers'] = {
        'contentType': request.headers.contentType?.toString(),
        'contentLength': request.headers.contentLength,
        'method': request.method,
      };

      // Try to read body directly
      try {
        final body = await utf8.decoder.bind(request).join();
        responseData['rawBody'] = body;
        responseData['rawBodyLength'] = body.length;
      } catch (e) {
        responseData['rawBodyError'] = e.toString();
      }

      // Try form parsing
      try {
        final form =  request.form();
        final allFields = await form.all();
        responseData['formFields'] = allFields;
        responseData['formFieldsCount'] = allFields.length;
      } catch (e) {
        responseData['formError'] = e.toString();
      }

      // Check query parameters
      responseData['queryParameters'] = request.uri.queryParameters;

      print('=== DEBUG FORM ===');
      print(responseData);

      return request.json(json.encode(responseData));


    } catch (e, stack) {
      responseData['globalError'] = e.toString();
      responseData['stackTrace'] = stack.toString();

      print('=== DEBUG FORM ERROR ===');
      print(responseData);

      return request.json(json.encode(responseData));
    }
  });

  router.get('/', (request) async {
    return request.view("welcome");
  });

  router.group(
    prefix: 'blog',
    routes: () {
      router.get('/', BlogPagesController.index);
      router.get('/{slug:string}', BlogPagesController.show);
    },
  );




}
