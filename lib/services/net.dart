/// `package:http` con tiempo límite.
///
/// Se importa en lugar de `package:http/http.dart` con el mismo prefijo
/// (`import 'net.dart' as http;`) y las llamadas `http.get/post/put` quedan
/// iguales. Sin límite, una red inestable deja los spinners girando para siempre;
/// al vencer se lanza `TimeoutException`, que los `catch` existentes ya manejan.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

export 'package:http/http.dart'
    hide get, post, put, patch, delete, head, read, readBytes;

const httpTimeout = Duration(seconds: 25);

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    http.get(url, headers: headers).timeout(httpTimeout);

Future<http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    http
        .post(url, headers: headers, body: body, encoding: encoding)
        .timeout(httpTimeout);

Future<http.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    http
        .put(url, headers: headers, body: body, encoding: encoding)
        .timeout(httpTimeout);
