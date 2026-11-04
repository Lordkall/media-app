import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../screens/clinic_profile_screen.dart';
import 'profile_avatar.dart';

class TopClinicsSection extends StatefulWidget {
  const TopClinicsSection({super.key});

  @override
  State<TopClinicsSection> createState() => _TopClinicsSectionState();
}

class _TopClinicsSectionState extends State<TopClinicsSection> {
  final ScrollController _controller = ScrollController();
  List<Map<String, dynamic>> _clinics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadClinics() async {
    try {
      final responses = await Future.wait([
        ApiClient.get('/users/me'),
        ApiClient.get('/clinics/'),
      ]);
      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final user = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final state = user['state']?.toString().trim() ?? '';
      final clinics = (jsonDecode(responses[1].body) as List<dynamic>)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((clinic) =>
              clinic['is_vip'] == true &&
              state.isNotEmpty &&
              clinic['state']?.toString().trim() == state)
          .toList();
      clinics.shuffle(math.Random());
      if (!mounted) return;
      setState(() {
        _clinics = clinics.take(5).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top clínicas',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B2545))),
          const SizedBox(height: 12),
          if (_loading)
            const SizedBox(
                height: 218, child: Center(child: CircularProgressIndicator()))
          else if (_clinics.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aún no hay clínicas VIP disponibles en tu estado.',
                  style: TextStyle(color: Color(0xFF475569))),
            )
          else
            SizedBox(
              height: 218,
              child: Scrollbar(
                controller: _controller,
                thumbVisibility:
                    defaultTargetPlatform == TargetPlatform.windows,
                trackVisibility:
                    defaultTargetPlatform == TargetPlatform.windows,
                notificationPredicate: (_) =>
                    defaultTargetPlatform == TargetPlatform.windows,
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.separated(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    itemCount: _clinics.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) =>
                        _clinicCard(_clinics[index]),
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _clinicCard(Map<String, dynamic> clinic) {
    final id = clinic['id'];
    final name = clinic['name']?.toString().trim().isNotEmpty == true
        ? clinic['name'].toString()
        : clinic['first_name']?.toString() ?? 'Clínica';
    final detail = clinic['description']?.toString().trim().isNotEmpty == true
        ? clinic['description'].toString()
        : clinic['address']?.toString() ?? 'Centro médico';
    return SizedBox(
      width: 122,
      height: 206,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: id == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => ClinicProfileScreen(clinic: clinic),
                  )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(5),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: ProfileAvatar(
                      imageUrl: clinic['avatar_url']?.toString(),
                      fallbackRole: 'clinic',
                      size: 112,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 4, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF17212B))),
                      const SizedBox(height: 3),
                      Text(detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF475569))),
                      const Spacer(),
                      const Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Color(0xFFF2B544), size: 15),
                          SizedBox(width: 3),
                          Text('VIP',
                              style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
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
