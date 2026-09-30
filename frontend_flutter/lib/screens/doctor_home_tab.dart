import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import '../widgets/doctor_header.dart';
import '../core/api_client.dart';
import '../core/profile_image_helper.dart';
import '../models/ve_catalogs.dart';
import '../widgets/profile_avatar.dart';
import 'select_plan_screen.dart';
import 'support_messages_screen.dart';

class DoctorHomeTab extends StatefulWidget {
  const DoctorHomeTab({super.key, this.onProfileTap, this.onCitasHoyTap});
  final VoidCallback? onProfileTap;
  final VoidCallback? onCitasHoyTap;

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  List<dynamic> _notifications = [];
  bool _isLoadingNotifications = true;
  bool _isLoadingProfile = true;
  int _citasHoy = 0;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _subData;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Poll every 30 seconds for real-time notification updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchData();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final responses = await Future.wait([
        ApiClient.get('/users/me'),
        ApiClient.get('/users/me/notifications'),
        ApiClient.get('/appointments/my'),
        ApiClient.get('/subscriptions/me'),
      ]);
      final user = responses[0].statusCode == 200
          ? Map<String, dynamic>.from(jsonDecode(responses[0].body))
          : null;
      final notifications = responses[1].statusCode == 200
          ? List<dynamic>.from(jsonDecode(responses[1].body))
          : _notifications;
      final appointments = responses[2].statusCode == 200
          ? List<dynamic>.from(jsonDecode(responses[2].body))
          : <dynamic>[];
      final subscription = responses[3].statusCode == 200
          ? Map<String, dynamic>.from(jsonDecode(responses[3].body))
          : null;
      final today = caracasNow().toIso8601String().split('T')[0];
      final appointmentsToday = appointments
          .where((appointment) =>
              appointment['date'].toString().startsWith(today) &&
              appointment['status'] == 'scheduled')
          .length;
      if (user != null)
        ProfileImageHelper.updateCurrentUserAvatar(
            user['avatar_url']?.toString());
      if (mounted) {
        setState(() {
          _userData = user ?? _userData;
          _notifications = notifications;
          _subData = subscription ?? _subData;
          _citasHoy = appointmentsToday;
          _isLoadingNotifications = false;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoadingNotifications = false;
          _isLoadingProfile = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3), Color(0xFFB3C6DF)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DoctorHeader(),
            const SizedBox(height: 16),
            _buildProfileSection(),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Menú principal',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2545)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const Text('Notificaciones Recientes',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  if (_isLoadingNotifications)
                    const Center(child: CircularProgressIndicator())
                  else if (_notifications.isEmpty)
                    const Text('No hay notificaciones recientes.',
                        style: TextStyle(color: Colors.grey))
                  else
                    ..._notifications.take(3).map((n) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE2F1F8),
                                child: Icon(Icons.notifications,
                                    color: Color(0xFF0056B3))),
                            title: Text(n['title'] ?? 'Notificación',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(n['message'] ?? '',
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: widget.onCitasHoyTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A896),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_available,
                                  color: Colors.white, size: 28),
                              SizedBox(width: 12),
                              Text('Citas para hoy',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_citasHoy',
                              style: const TextStyle(
                                  color: Color(0xFF00A896),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF0056B3), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Mi Suscripción',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0B2545))),
                            Icon(Icons.star, color: Color(0xFF0056B3)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Builder(builder: (context) {
                          final rawPlan =
                              _subData?['current']?['plan'] ?? 'Ninguno';
                          final displayPlan = rawPlan == 'sponsored'
                              ? 'VIP'
                              : rawPlan == 'basic'
                                  ? 'Básico'
                                  : rawPlan == 'featured'
                                      ? 'Destacado'
                                      : rawPlan;
                          return Text('Plan Actual: $displayPlan',
                              style: const TextStyle(
                                  fontSize: 16, color: Color(0xFF475569)));
                        }),
                        const SizedBox(height: 8),
                        Text(
                            'Vence: ${_subData?['current']?['end_date']?.toString().split('T')[0] ?? '--'}',
                            style: const TextStyle(
                                fontSize: 16, color: Color(0xFF475569))),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_userData != null) {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => SelectPlanScreen(
                                        doctorData: _userData!,
                                        isRenewal: true)));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0056B3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Renovar o Cambiar Plan',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SupportMessagesScreen()));
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withOpacity(0.5),
                    leading: const Icon(Icons.forum, color: Color(0xFF0056B3)),
                    title: const Text('Buzón de Mensajes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B2545))),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFF0B2545)),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    if (_isLoadingProfile) {
      return const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator()));
    }
    final bool isVip = _subData?['current']?['plan'] == 'sponsored';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          InkWell(
            onTap: widget.onProfileTap,
            customBorder: const CircleBorder(),
            child: ProfileAvatar(
              imageUrl: _userData?['avatar_url']?.toString(),
              currentUser: true,
              fallbackRole: _userData?['role']?.toString() ?? 'doctor',
              size: 80,
              borderColor:
                  isVip ? const Color(0xFFFFC107) : const Color(0xFF0056B3),
              borderWidth: 3,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0B2545))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFF38B6FF),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          _userData?['role'] == 'assistant'
                              ? 'Asistente'
                              : 'Doctor',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            _userData?['email'] ?? 'doctor@saludnow.com',
                            style: const TextStyle(
                                color: Color(0xFF475569), fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _greeting {
    final user = _userData ?? const <String, dynamic>{};
    final role = user['role']?.toString();
    final firstName = user['first_name']?.toString().trim() ?? '';
    if (role == 'clinic')
      return '¡Hola, ${firstName.isEmpty ? 'Clínica' : firstName}!';
    if (role == 'assistant')
      return '¡Hola, asistente ${firstName.isEmpty ? '' : firstName}!';
    final lastName = user['last_name']?.toString().trim() ?? '';
    final gender = user['gender']?.toString().toLowerCase() ?? '';
    final title =
        gender.startsWith('f') || gender.contains('femen') ? 'Dra.' : 'Dr.';
    final fullName =
        [lastName, firstName].where((name) => name.isNotEmpty).join(' ');
    return '¡Hola, $title ${fullName.isEmpty ? 'Doctor' : fullName}!';
  }
}
