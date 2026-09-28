import 'package:flutter/material.dart';
import '../core/profile_image_helper.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final bool currentUser;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 64,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
    this.currentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUser) {
      return ValueListenableBuilder<String?>(
        valueListenable: ProfileImageHelper.currentUserAvatarUrl,
        builder: (context, currentUrl, _) =>
            _buildImage(currentUrl ?? imageUrl),
      );
    }
    return _buildImage(imageUrl);
  }

  Widget _buildImage(String? url) {
    final innerSize = (size - borderWidth * 2).clamp(0, size).toDouble();
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
        child: Image(
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
