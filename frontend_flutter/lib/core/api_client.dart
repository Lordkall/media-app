import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'https://media-app-production-dd3f.up.railway.app/api/v1';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    return await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> postForm(String endpoint, Map<String, String> body) async {
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

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
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

  static Future<String?> uploadFile(String endpoint, String filePath) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', url);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    
    final response = await request.send();
    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final data = jsonDecode(resStr);
      return data['avatar_url'];
    }
    return null;
  }

  static Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    return await http.patch(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }
}
