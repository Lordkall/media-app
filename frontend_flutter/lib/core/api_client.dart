import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'https://saludnow.site/api/v1';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> post(
      String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    return await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> postForm(
      String endpoint, Map<String, String> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    return await http.post(
      url,
      headers: headers,
      body: body,
    );
  }

  static Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    return await http.get(url, headers: headers);
  }

  static Future<http.Response> put(
      String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    return await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    return await http.delete(url, headers: headers);
  }

  static Future<String?> uploadFile(String endpoint,
      {required List<int> bytes, required String filename}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', url);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final extension =
        filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    final subtype = switch (extension) {
      'jpg' || 'jpeg' => 'jpeg',
      'png' => 'png',
      'gif' => 'gif',
      'webp' => 'webp',
      _ => 'octet-stream',
    };
    final contentType = subtype == 'octet-stream'
        ? MediaType('application', 'octet-stream')
        : MediaType('image', subtype);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: contentType,
    ));

    final response = await request.send();
    final resStr = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final data = jsonDecode(resStr);
      return data['avatar_url'];
    }
    var detail = resStr.trim();
    try {
      final payload = jsonDecode(resStr);
      if (payload is Map && payload['detail'] != null) {
        detail = payload['detail'].toString();
      }
    } catch (_) {}
    detail = detail.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (detail.length > 180) detail = '${detail.substring(0, 180)}…';
    throw Exception(
        'El servidor rechazó la imagen (${response.statusCode})${detail.isEmpty ? '' : ': $detail'}');
  }

  static Future<http.Response> patch(
      String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    return await http.patch(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }
}
