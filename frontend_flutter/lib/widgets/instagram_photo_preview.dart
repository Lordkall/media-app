import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/profile_image_helper.dart';
import '../models/avatar_catalog.dart';
import 'avatar_sprite.dart';

/// Modal estilo Instagram que expande una foto o avatar de forma cuadrada
/// con fondo difuminado y oscuro al dejarlo presionado.
class InstagramPhotoPreview {
  static void show(
    BuildContext context, {
    required String? imageUrl,
    String fallbackRole = 'patient',
    String? title,
    String? subtitle,
  }) {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar foto',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, secondaryAnim) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curvedAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final fadeAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );

        return _InstagramPhotoDialog(
          scaleAnimation: curvedAnim,
          fadeAnimation: fadeAnim,
          imageUrl: imageUrl,
          fallbackRole: fallbackRole,
          title: title,
          subtitle: subtitle,
        );
      },
    );
  }
}

class _InstagramPhotoDialog extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final Animation<double> fadeAnimation;
  final String? imageUrl;
  final String fallbackRole;
  final String? title;
  final String? subtitle;

  const _InstagramPhotoDialog({
    required this.scaleAnimation,
    required this.fadeAnimation,
    required this.imageUrl,
    required this.fallbackRole,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardSize = math.min(
      screenSize.width * 0.82,
      math.min(screenSize.height * 0.50, 330.0),
    );

    final url = imageUrl?.trim();
    final preset = AvatarCatalog.parse(url);
    final defaultAvatar = url == null || url.isEmpty;
    final spriteRole = preset?.role ?? AvatarCatalog.normalizeRole(fallbackRole);
    final spriteIndex = preset?.index ?? 0;

    return FadeTransition(
      opacity: fadeAnimation,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 150) {
            Navigator.of(context).pop();
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // Fondo oscuro con desenfoque tipo Instagram
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withOpacity(0.72),
                ),
              ),

              // Contenido central centrado
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Foto cuadrada expandida con animación pop
                        ScaleTransition(
                          scale: Tween<double>(begin: 0.65, end: 1.0)
                              .animate(scaleAnimation),
                          child: Container(
                            width: cardSize,
                            height: cardSize,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0EAFC),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.28),
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.45),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: preset != null ||
                                        defaultAvatar ||
                                        (url?.startsWith('preset:') ?? false)
                                    ? AvatarSprite(
                                        key: ValueKey(
                                            '$spriteRole:$spriteIndex'),
                                        role: spriteRole,
                                        index: spriteIndex,
                                        size: cardSize,
                                      )
                                    : Image(
                                        key: ValueKey(url),
                                        width: cardSize,
                                        height: cardSize,
                                        image: ProfileImageHelper
                                            .getProfileImageProvider(url),
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.high,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          color: const Color(0xFFE0EAFC),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.person,
                                            color: const Color(0xFF0056B3),
                                            size: cardSize * 0.55,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        // Título / Nombre
                        if (title != null && title!.trim().isNotEmpty) ...[
                          const SizedBox(height: 18),
                          FadeTransition(
                            opacity: fadeAnimation,
                            child: Text(
                              title!.trim(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Subtítulo / Especialidad / Rol
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          FadeTransition(
                            opacity: fadeAnimation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                subtitle!.trim(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Indicador discreto para cerrar
                        const SizedBox(height: 22),
                        FadeTransition(
                          opacity: fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.14),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Toca en cualquier lugar para cerrar',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

