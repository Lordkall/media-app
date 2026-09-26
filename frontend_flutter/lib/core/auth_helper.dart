import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthHelper {
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      String payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 0: break;
        case 2: payload += '=='; break;
        case 3: payload += '='; break;
        default: return null;
      }
      
      final String decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded);
    } catch (e) {
      print('Error decoding token: $e');
      return null;
    }
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;
    
    final decoded = decodeToken(token);
    return decoded?['role']?.toString();
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final currentToken = prefs.getString('access_token');
    if (currentToken != null) {
      await prefs.setString('saved_biometric_token', currentToken);
    }
    await prefs.remove('access_token');
  }
}
