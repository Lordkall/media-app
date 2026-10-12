import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'profile_image_helper.dart';
import 'api_client.dart';

class AuthHelper {
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      String payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 0:
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        default:
          return null;
      }

      final String decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded);
    } catch (e) {
      debugPrint('Error decoding token: $e');
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

  static String? getUserIdFromToken(String? token) {
    if (token == null) return null;
    final decoded = decodeToken(token);
    return decoded?['id']?.toString() ?? decoded?['sub']?.toString();
  }

  static String? getEmailFromToken(String? token) {
    if (token == null) return null;
    final decoded = decodeToken(token);
    return decoded?['sub']?.toString();
  }

  static Future<void> logout({bool preserveBiometricToken = true}) async {
    ProfileImageHelper.updateCurrentUserAvatar(null);
    final prefs = await SharedPreferences.getInstance();
    final currentToken = prefs.getString('access_token');
    final userId = getUserIdFromToken(currentToken) ?? 'default';

    if (!kIsWeb && currentToken != null) {
      try {
        await ApiClient.put('/users/me', {'fcm_token': null});
      } catch (error) {
        debugPrint('Could not unregister this device token: $error');
      }
    }
    final biometricsEnabled = prefs.getBool('biometrics_enabled_$userId') ?? false;
    if (!kIsWeb && preserveBiometricToken && biometricsEnabled && currentToken != null) {
      await prefs.setString('saved_biometric_token', currentToken);
      await prefs.setString('saved_biometric_user_id', userId);
    } else {
      await prefs.remove('saved_biometric_token');
      await prefs.remove('saved_biometric_user_id');
      await prefs.remove('logged_username');
      await prefs.setBool('biometrics_enabled', false);
    }
    await prefs.remove('access_token');
  }
}
