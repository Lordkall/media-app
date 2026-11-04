import 'dart:async';
import 'dart:convert';

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
    if (ad == null) return const SizedBox.shrink();
    final id = int.tryParse(ad['id']?.toString() ?? '');
    final expiration =
        DateTime.tryParse(ad['expires_at']?.toString() ?? '')?.toLocal();
    if (id == null ||
        expiration == null ||
        !expiration.isAfter(DateTime.now())) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: .22),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InkWell(
              onTap: _openCurrentAd,
              child: Image.network(
                _imageUrl(ad['image_url']?.toString() ?? ''),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                errorBuilder: (_, __, ___) {
                  _handleImageError(id);
                  return const SizedBox.shrink();
                },
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black.withValues(alpha: .56),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Cerrar anuncio',
                  visualDensity: VisualDensity.compact,
                  onPressed: _dismissCurrent,
                  icon: const Icon(Icons.close_rounded,
                      size: 19, color: Colors.white),
                ),
              ),
            ),
            if ((ad['title']?.toString().trim().isNotEmpty ?? false))
              Positioned(
                left: 10,
                bottom: 8,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      ad['title'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
