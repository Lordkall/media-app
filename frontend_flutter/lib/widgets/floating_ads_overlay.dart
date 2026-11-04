import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';

class FloatingAdsOverlay extends StatefulWidget {
  const FloatingAdsOverlay({super.key});

  @override
  State<FloatingAdsOverlay> createState() => _FloatingAdsOverlayState();
}

class _FloatingAdsOverlayState extends State<FloatingAdsOverlay> {
  List<Map<String, dynamic>> _ads = [];
  int _index = 0;
  String _viewerId = 'device';
  final Set<int> _failedIds = {};
  Timer? _refreshTimer;

  Map<String, dynamic>? get _currentAd =>
      _index >= 0 && _index < _ads.length ? _ads[_index] : null;

  @override
  void initState() {
    super.initState();
    _loadAds();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final expiresAt =
          DateTime.tryParse(_currentAd?['expires_at']?.toString() ?? '')
              ?.toLocal();
      if (_currentAd == null ||
          expiresAt == null ||
          !expiresAt.isAfter(DateTime.now())) {
        _loadAds();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAds() async {
    try {
      final responses = await Future.wait([
        ApiClient.get('/ads/active'),
        ApiClient.get('/users/me'),
      ]);
      if (responses[0].statusCode != 200) return;
      final prefs = await SharedPreferences.getInstance();
      if (responses[1].statusCode == 200) {
        final user = jsonDecode(responses[1].body) as Map<String, dynamic>;
        _viewerId = user['id']?.toString() ?? 'device';
      }
      final now = DateTime.now();
      final activeAds = (jsonDecode(responses[0].body) as List<dynamic>)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((ad) {
        final expiration =
            DateTime.tryParse(ad['expires_at']?.toString() ?? '')?.toLocal();
        final id = int.tryParse(ad['id']?.toString() ?? '');
        if (id == null || expiration == null || !expiration.isAfter(now)) {
          return false;
        }
        return !(prefs.getBool(_dismissKey(id)) ?? false) &&
            !_failedIds.contains(id);
      }).toList();
      if (!mounted) return;
      setState(() {
        _ads = activeAds;
        _index = 0;
      });
      final firstId = int.tryParse(_currentAd?['id']?.toString() ?? '');
      if (firstId != null) unawaited(_recordEvent(firstId, 'view'));
    } catch (_) {
      // An ad service failure never blocks the screen behind it.
      if (mounted) setState(() => _ads = []);
    }
  }

  String _dismissKey(int adId) => 'dismissed_floating_ad_${_viewerId}_$adId';

  Future<void> _recordEvent(int adId, String event) async {
    try {
      await ApiClient.post('/ads/$adId/$event', {});
    } catch (_) {
      // Metrics are best-effort and do not interrupt the user flow.
    }
  }

  Future<void> _dismissCurrent() async {
    final adId = int.tryParse(_currentAd?['id']?.toString() ?? '');
    if (adId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dismissKey(adId), true);
    } catch (_) {}
    _showNextAd();
  }

  void _showNextAd() {
    if (!mounted) return;
    if (_index + 1 >= _ads.length) {
      setState(() => _ads = []);
      return;
    }
    setState(() => _index++);
    final nextId = int.tryParse(_currentAd?['id']?.toString() ?? '');
    if (nextId != null) unawaited(_recordEvent(nextId, 'view'));
  }

  void _handleImageError(int adId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _failedIds.contains(adId)) return;
      _failedIds.add(adId);
      _showNextAd();
    });
  }

  Future<void> _openCurrentAd() async {
    final ad = _currentAd;
    if (ad == null) return;
    final id = int.tryParse(ad['id']?.toString() ?? '');
    if (id != null) unawaited(_recordEvent(id, 'click'));
    final rawUrl = ad['link_url']?.toString().trim() ?? '';
    if (rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Keep the banner stable if the destination cannot be opened.
    }
  }

  String _imageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://saludnow.site${value.startsWith('/') ? '' : '/'}$value';
  }

  @override
  Widget build(BuildContext context) {
    final ad = _currentAd;
    if (ad == null) return const IgnorePointer(child: SizedBox.shrink());
    final id = int.tryParse(ad['id']?.toString() ?? '');
    final expiration =
        DateTime.tryParse(ad['expires_at']?.toString() ?? '')?.toLocal();
    if (id == null ||
        expiration == null ||
        !expiration.isAfter(DateTime.now())) {
      return const IgnorePointer(child: SizedBox.shrink());
    }

    final size = MediaQuery.sizeOf(context);
    final cardWidth = math.min(size.width * 0.88, 400.0);
    final cardHeight = math.min(size.height * 0.66, 540.0);
    final title = ad['title']?.toString().trim() ?? '';
    final hasTitle = title.isNotEmpty;
    final linkUrl = ad['link_url']?.toString().trim() ?? '';
    final hasLink = linkUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fondo difuminado (blur) que bloquea todas las interacciones
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // Bloquea toques al contenido de fondo
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
          // 2. Tarjeta del anuncio modal abarcando el área central
          Center(
            child: Container(
              width: cardWidth,
              height: cardHeight,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagen del anuncio (al tocar abre enlace si existe)
                  InkWell(
                    onTap: hasLink ? _openCurrentAd : null,
                    child: Image.network(
                      _imageUrl(ad['image_url']?.toString() ?? ''),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF0056B3),
                                  ),
                                ),
                      errorBuilder: (_, __, ___) {
                        _handleImageError(id);
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  // Degradado inferior para título y botón de acción
                  if (hasTitle || hasLink)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.88),
                              Colors.black.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasTitle)
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            if (hasLink) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 42,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF0756A4),
                                        Color(0xFF0A3D78)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(21),
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _openCurrentAd,
                                    icon: const Icon(Icons.open_in_new,
                                        size: 16, color: Colors.white),
                                    label: const Text(
                                      'Ver más',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(21),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  // Botón de cerrar (X) en la esquina superior derecha
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _dismissCurrent,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.close_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
