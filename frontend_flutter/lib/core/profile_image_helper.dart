import 'package:flutter/material.dart';

class ProfileImageHelper {
  static final ValueNotifier<String?> currentUserAvatarUrl =
      ValueNotifier(null);

  static void updateCurrentUserAvatar(String? url) {
    currentUserAvatarUrl.value = url;
  }

  static ImageProvider getProfileImageProvider(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      final finalUrl = avatarUrl.trim();
      if (finalUrl.startsWith('https://')) {
        return NetworkImage(finalUrl);
      }
      if (finalUrl.startsWith('http://')) {
        return NetworkImage(finalUrl.replaceFirst('http://', 'https://'));
      }
      final String path;
      if (finalUrl.startsWith('/api/v1/')) {
        path = finalUrl;
      } else if (finalUrl.startsWith('/uploads/')) {
        path = '/api/v1$finalUrl';
      } else if (finalUrl.startsWith('uploads/')) {
        path = '/api/v1/$finalUrl';
      } else if (finalUrl.startsWith('/avatars/')) {
        path = '/api/v1/uploads$finalUrl';
      } else if (finalUrl.startsWith('avatars/')) {
        path = '/api/v1/uploads/$finalUrl';
      } else if (finalUrl.startsWith('/')) {
        path = finalUrl;
      } else {
        path = '/api/v1/uploads/avatars/${finalUrl.split('/').last}';
      }
      return NetworkImage('https://saludnow.site$path');
    }
    return const NetworkImage(
        'https://cdn-icons-png.flaticon.com/512/3069/3069172.png');
  }
}
