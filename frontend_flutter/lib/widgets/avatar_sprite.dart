import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/avatar_catalog.dart';

class AvatarSprite extends StatefulWidget {
  const AvatarSprite({
    super.key,
    required this.role,
    required this.index,
    required this.size,
  });

  final String role;
  final int index;
  final double size;

  @override
  State<AvatarSprite> createState() => _AvatarSpriteState();
}

class _AvatarSpriteState extends State<AvatarSprite> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ui.Image? _image;

  String get _assetPath => AvatarCatalog.assetForRole(widget.role);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant AvatarSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) _resolveImage();
  }

  void _resolveImage() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    final stream = AssetImage(_assetPath).resolve(
      createLocalImageConfiguration(context),
    );
    _imageStream = stream;
    _imageListener = ImageStreamListener((info, synchronousCall) {
      if (mounted) setState(() => _image = info.image);
    });
    stream.addListener(_imageListener!);
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final availableSide = math.min(
            constraints.maxWidth.isFinite ? constraints.maxWidth : widget.size,
            constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : widget.size,
          );
          final side =
              widget.size.isFinite ? widget.size : availableSide.toDouble();
          return SizedBox.square(
            dimension: side,
            child: CustomPaint(
              painter: _AvatarSpritePainter(
                image: _image,
                index: widget.index,
                columns: AvatarCatalog.columnsForRole(widget.role),
                rows: AvatarCatalog.rowsForRole(widget.role),
              ),
            ),
          );
        },
      );
}

class _AvatarSpritePainter extends CustomPainter {
  const _AvatarSpritePainter({
    required this.image,
    required this.index,
    required this.columns,
    required this.rows,
  });

  final ui.Image? image;
  final int index;
  final int columns;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE0F4FA);
    canvas.drawRect(Offset.zero & size, background);
    final sourceImage = image;
    if (sourceImage == null) return;

    final column = index % columns;
    final row = index ~/ columns;
    final cellWidth = sourceImage.width / columns;
    // Avatar sheets use square tiles spaced by their width. The five-column
    // sheets leave extra canvas below the last row; equal-height row slicing
    // therefore cuts off the bottom of each portrait.
    final sourceSide = cellWidth.toDouble();
    final rowPitch = sourceSide;
    final topInset = math.max(
      0.0,
      (sourceImage.height - rows * rowPitch) / 2 - sourceSide * 0.07,
    );
    final sourceRect = Rect.fromLTWH(
      column * cellWidth,
      topInset + row * rowPitch,
      sourceSide,
      sourceSide,
    );
    canvas.drawImageRect(
      sourceImage,
      sourceRect,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarSpritePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.index != index ||
      oldDelegate.columns != columns ||
      oldDelegate.rows != rows;
}
