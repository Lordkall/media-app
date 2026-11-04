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
  final Set<int> _sessionDismissedIds = {};
  bool _dontShowAgain = false;
  bool _isClosing = false;
  Timer? _refreshTimer;

  Map<String, dynamic>? get _currentAd =>
      !_isClosing && _index >= 0 && _index < _ads.length ? _ads[_index] : null;

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
            !_sessionDismissedIds.contains(id) &&
            !_failedIds.contains(id);
      }).toList();
      if (!mounted) return;
      setState(() {
        _ads = activeAds;
        _index = 0;
        _dontShowAgain = false;
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

  void _dismissCurrent() {
    if (_isClosing) return;
    final ad = _currentAd;
    final adId = int.tryParse(ad?['id']?.toString() ?? '');

    // Si marcó "No mostrar más este anuncio", se guarda permanentemente en almacenamiento
    if (adId != null && _dontShowAgain) {
      unawaited(SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(_dismissKey(adId), true);
      }));
    } else if (adId != null) {
      // Si no lo marcó, solo se oculta en la sesión actual
      _sessionDismissedIds.add(adId);
    }

    // Cierre inmediato instantáneo para evitar cuadros blancos o congelamiento
    setState(() {
      _isClosing = true;
      _dontShowAgain = false;
      if (_index + 1 >= _ads.length) {
        _ads = [];
      } else {
        _index++;
      }
      _isClosing = false;
    });

    final nextId = int.tryParse(_currentAd?['id']?.toString() ?? '');
    if (nextId != null) unawaited(_recordEvent(nextId, 'view'));
  }

  void _handleImageError(int adId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _failedIds.contains(adId)) return;
      _failedIds.add(adId);
      _dismissCurrent();
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
    if (ad == null || _isClosing) {
      return const IgnorePointer(child: SizedBox.shrink());
    }
    final id = int.tryParse(ad['id']?.toString() ?? '');
    final expiration =
        DateTime.tryParse(ad['expires_at']?.toString() ?? '')?.toLocal();
    if (id == null ||
        expiration == null ||
        !expiration.isAfter(DateTime.now())) {
      return const IgnorePointer(child: SizedBox.shrink());
    }

    final size = MediaQuery.sizeOf(context);
    final cardWidth = math.min(size.width * 0.88, 390.0);
    final cardHeight = math.min(size.height * 0.60, 500.0);
    final title = ad['title']?.toString().trim() ?? '';
    final hasTitle = title.isNotEmpty;
    final linkUrl = ad['link_url']?.toString().trim() ?? '';
    final hasLink = linkUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fondo difuminado que bloquea todas las interacciones con el fondo
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // Bloquea toques a la pantalla de fondo
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
          // 2. Contenido central: Anuncio + Cuadrito para tildar debajo
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tarjeta del anuncio
                  Container(
                    width: cardWidth,
                    height: cardHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
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
                                          borderRadius:
                                              BorderRadius.circular(21),
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
                                            backgroundColor:
                                                Colors.transparent,
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
                  const SizedBox(height: 14),
                  // Cuadrito para tildar: No mostrar más este anuncio
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Theme(
                            data: ThemeData(
                              unselectedWidgetColor: Colors.white,
                            ),
                            child: Checkbox(
                              value: _dontShowAgain,
                              onChanged: (val) => setState(
                                  () => _dontShowAgain = val ?? false),
                              activeColor: const Color(0xFF38B6FF),
                              checkColor: const Color(0xFF0B2545),
                              side: const BorderSide(
                                  color: Colors.white, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'No mostrar más este anuncio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ],
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
        ],
      ),
    );
  }
}
