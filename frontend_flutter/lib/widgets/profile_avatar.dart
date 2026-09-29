import 'package:flutter/material.dart';
import '../core/profile_image_helper.dart';
import '../models/avatar_catalog.dart';
import 'avatar_sprite.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final bool currentUser;
  final String fallbackRole;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 64,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
    this.currentUser = false,
    this.fallbackRole = 'patient',
  });

  @override
  Widget build(BuildContext context) {
    if (currentUser) {
      return ValueListenableBuilder<String?>(
        valueListenable: ProfileImageHelper.currentUserAvatarUrl,
        builder: (context, currentUrl, _) => _buildImage(
          currentUrl ?? imageUrl,
          fallbackRole,
        ),
      );
    }
    return _buildImage(imageUrl, fallbackRole);
  }

  Widget _buildImage(String? url, String role) {
    final innerSize = (size - borderWidth * 2).clamp(0, size).toDouble();
    final preset = AvatarCatalog.parse(url);
    final defaultAvatar = url == null || url.trim().isEmpty;
    final spriteRole = preset?.role ?? AvatarCatalog.normalizeRole(role);
    final spriteIndex = preset?.index ?? 0;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        color: const Color(0xFFE0EAFC),
      ),
      child: ClipOval(
        child: preset != null || defaultAvatar || url.startsWith('preset:')
            ? AvatarSprite(
                key: ValueKey('$spriteRole:$spriteIndex'),
                role: spriteRole,
                index: spriteIndex,
                size: innerSize,
              )
            : Image(
                key: ValueKey(url),
                width: innerSize,
                height: innerSize,
                image: ProfileImageHelper.getProfileImageProvider(url),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFE0EAFC),
                  alignment: Alignment.center,
                  child: Icon(Icons.person,
                      color: const Color(0xFF0056B3), size: innerSize * 0.58),
                ),
              ),
      ),
    );
  }
}
