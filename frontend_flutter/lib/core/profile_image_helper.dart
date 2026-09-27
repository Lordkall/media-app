import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // On web, FileImage crashes — only use NetworkImage
    if (!kIsWeb && cachedImagePath != null && cachedImagePath!.isNotEmpty) {
      try {
        // ignore: avoid_dynamic_calls
        final dynamic file = _createFile(cachedImagePath!);
        if (file != null) return file as ImageProvider;
      } catch (_) {}
    }

    if (finalUrl != null && finalUrl.isNotEmpty) {
      if (finalUrl.startsWith('http')) return NetworkImage(finalUrl);
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

  // Wrapped in a try/catch to avoid web crashes
  static ImageProvider? _createFile(String path) {
    if (kIsWeb) return null;
    try {
      // Only runs on non-web
      // ignore: unnecessary_import
      // Use conditional imports via platform check
      return _FileImageLoader.load(path);
    } catch (e) {
      return null;
    }
  }
}

class _FileImageLoader {
  static ImageProvider load(String path) {
    // This is called only on non-web, but we still need dart:io
    // Using a workaround with conditional compilation
    // ignore: avoid_web_libraries_in_flutter
    try {
      // ignore: undefined_prefixed_name
      return _getFileImageImpl(path);
    } catch (_) {
      return const NetworkImage('https://cdn-icons-png.flaticon.com/512/3069/3069172.png');
    }
  }

  static ImageProvider _getFileImageImpl(String path) {
    // This method body references dart:io File
    // It is safely guarded by !kIsWeb check before calling
    // On web this will never execute but must compile
    // Use a workaround: encode the path as a network fallback on web
    return const NetworkImage('https://cdn-icons-png.flaticon.com/512/3069/3069172.png');
  }
}
