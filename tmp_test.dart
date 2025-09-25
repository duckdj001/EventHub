import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final server = await HttpServer.bind('127.0.0.1', 8085);
  server.listen((request) async {
    final bytes = await request.fold<List<int>>(<int>[], (prev, element) {
      prev.addAll(element);
      return prev;
    });
    print('Server received: \\${utf8.decode(bytes)}');
    request.response
      ..statusCode = 200
      ..write('ok');
    await request.response.close();
  });

  final client = http.Client();
  final request = http.StreamedRequest('PUT', Uri.parse('http://127.0.0.1:8085/test'));
  request.headers['Content-Type'] = 'text/plain';
  request.contentLength = 11;
  request.sink.add(utf8.encode('hello world'));
  print('Added data');
  await request.sink.close();
  print('Closed sink');
  final response = await client.send(request);
  print('Response status: \\${response.statusCode}');
  final respBody = await response.stream.bytesToString();
  print('Body: $respBody');
  client.close();
  await server.close(force: true);
}
