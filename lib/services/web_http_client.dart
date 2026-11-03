import 'package:http/http.dart' as http;

import 'web_http_client_stub.dart'
    if (dart.library.html) 'web_http_client_web.dart' as implementation;

http.Client createWebHttpClient() => implementation.createClient();
