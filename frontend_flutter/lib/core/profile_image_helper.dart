import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_helper.dart';

class ProfileImageHelper {
  static String? cachedImagePath;
  static String? cachedAvatarUrl;

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
    if (avatarUrl != null) {
      cachedAvatarUrl = avatarUrl;
    }
    String? finalUrl = avatarUrl ?? cachedAvatarUrl;

    if (cachedImagePath != null && cachedImagePath!.isNotEmpty) {
      return FileImage(File(cachedImagePath!));
    }
    if (finalUrl != null && finalUrl.isNotEmpty) {
      if (finalUrl.startsWith('http')) return NetworkImage(finalUrl);
      final path = finalUrl.startsWith('/') ? finalUrl : '/uploads/avatars/$finalUrl';
      return NetworkImage('https://media-app-production-dd3f.up.railway.app$path');
    }
    return const NetworkImage('https://cdn-icons-png.flaticon.com/512/3069/3069172.png');
  }
}
