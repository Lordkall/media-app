import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileImageHelper {
  static String? cachedImagePath;

  static Future<String> _getKey() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('logged_username') ?? 'default';
    return 'profile_image_path_$username';
  }

  static Future<void> saveImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    await prefs.setString(key, path);
    cachedImagePath = path;
  }

  static Future<String?> getImagePath() async {
    if (cachedImagePath != null) return cachedImagePath;
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    cachedImagePath = prefs.getString(key);
    return cachedImagePath;
  }

  static ImageProvider getProfileImageProvider(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      final finalUrl = avatarUrl.trim();
      if (finalUrl.startsWith('http://') || finalUrl.startsWith('https://')) {
        return NetworkImage(finalUrl);
      }
      // Ensure correct path prefix
      final String path;
      if (finalUrl.startsWith('/api/v1/')) {
        path = finalUrl;
      } else if (finalUrl.startsWith('/')) {
        path = finalUrl;
      } else {
        path = '/api/v1/uploads/avatars/$finalUrl';
      }
      return NetworkImage('https://saludnow.site$path');
    }
    return const NetworkImage('https://cdn-icons-png.flaticon.com/512/3069/3069172.png');
  }
}
