import 'package:flutter/material.dart';
import '../core/profile_image_helper.dart';
import '../models/avatar_catalog.dart';
import 'avatar_sprite.dart';
import 'instagram_photo_preview.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final bool currentUser;
  final String fallbackRole;
  final bool enableLongPress;
  final String? displayName;
  final String? subtitle;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 64,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
    this.currentUser = false,
    this.fallbackRole = 'patient',
    this.enableLongPress = true,
    this.displayName,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUser) {
      return ValueListenableBuilder<String?>(
        valueListenable: ProfileImageHelper.currentUserAvatarUrl,
        builder: (context, currentUrl, _) {
          final resolvedUrl = currentUrl ?? imageUrl;
          return _wrapWithLongPress(
            context,
            resolvedUrl,
            _buildImage(resolvedUrl, fallbackRole),
          );
        },
      );
    }
    return _wrapWithLongPress(
      context,
      imageUrl,
      _buildImage(imageUrl, fallbackRole),
    );
  }

  Widget _wrapWithLongPress(
      BuildContext context, String? resolvedUrl, Widget child) {
    if (!enableLongPress) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        InstagramPhotoPreview.show(
          context,
          imageUrl: resolvedUrl,
          fallbackRole: fallbackRole,
          title: displayName,
          subtitle: subtitle,
        );
      },
      child: child,
    );
  }

  Widget _buildImage(String? url, String role) {
    final innerSize = (size - borderWidth * 2).clamp(0, size).toDouble();
    final preset = AvatarCatalog.parse(url);
    final defaultAvatar = url == null || url.trim().isEmpty;
    final spriteRole = preset?.role ?? AvatarCatalog.normalizeRole(role);
    final spriteIndex = preset?.index ?? 0;
    final cornerRadius = size * 0.22;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        color: const Color(0xFFE0EAFC),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
            (cornerRadius - borderWidth).clamp(0, cornerRadius).toDouble()),
        child: preset != null || defaultAvatar || (url != null && url.startsWith('preset:'))
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
                filterQuality: FilterQuality.high,
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
