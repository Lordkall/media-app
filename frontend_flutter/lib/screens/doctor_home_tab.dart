import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import '../widgets/doctor_header.dart';
import '../core/api_client.dart';
import '../core/profile_image_helper.dart';
import 'select_plan_screen.dart';
import 'support_messages_screen.dart';

class DoctorHomeTab extends StatefulWidget {
  const DoctorHomeTab({super.key});

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  List<dynamic> _notifications = [];
  bool _isLoadingNotifications = true;
  int _citasHoy = 0;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _subData;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final userResponse = await ApiClient.get('/users/me');
      if (userResponse.statusCode == 200) {
        if (mounted) setState(() => _userData = jsonDecode(userResponse.body));
      }
      
      final notifResponse = await ApiClient.get('/users/me/notifications');
      if (notifResponse.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifications = jsonDecode(notifResponse.body);
            _isLoadingNotifications = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingNotifications = false);
      }

      final apptResponse = await ApiClient.get('/appointments/my');
      if (apptResponse.statusCode == 200) {
        final List<dynamic> appts = jsonDecode(apptResponse.body);
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        int count = 0;
        for (var a in appts) {
          if (a['date'].toString().startsWith(todayStr) && a['status'] == 'scheduled') {
            count++;
          }
        }
        if (mounted) {
          setState(() {
            _citasHoy = count;
          });
        }
      }

      final subResponse = await ApiClient.get('/subscriptions/me');
      if (subResponse.statusCode == 200) {
        if (mounted) setState(() => _subData = jsonDecode(subResponse.body));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNotifications = false);
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0B2545)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const Text('Notificaciones Recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  if (_isLoadingNotifications)
                    const Center(child: CircularProgressIndicator())
                  else if (_notifications.isEmpty)
                    const Text('No hay notificaciones recientes.', style: TextStyle(color: Colors.grey))
                  else
                    ..._notifications.take(3).map((n) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xFFE2F1F8), child: Icon(Icons.notifications, color: Color(0xFF0056B3))),
                            title: Text(n['title'] ?? 'Notificación', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(n['message'] ?? '', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A896),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.event_available, color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Text('Citas para hoy', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                            style: const TextStyle(color: Color(0xFF00A896), fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0056B3), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Mi Suscripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                            Icon(Icons.star, color: Color(0xFF0056B3)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Builder(builder: (context) {
                          final rawPlan = _subData?['current']?['plan'] ?? 'Ninguno';
                          final displayPlan = rawPlan == 'sponsored' ? 'VIP' : rawPlan == 'basic' ? 'Básico' : rawPlan == 'featured' ? 'Destacado' : rawPlan;
                          return Text('Plan Actual: $displayPlan', style: const TextStyle(fontSize: 16, color: Color(0xFF475569)));
                        }),
                        const SizedBox(height: 8),
                        Text('Vence: ${_subData?['current']?['end_date']?.toString().split('T')[0] ?? '--'}', style: const TextStyle(fontSize: 16, color: Color(0xFF475569))),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_userData != null) {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SelectPlanScreen(doctorData: _userData!, isRenewal: true)));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0056B3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Renovar o Cambiar Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportMessagesScreen()));
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withOpacity(0.5),
                    leading: const Icon(Icons.forum, color: Color(0xFF0056B3)),
                    title: const Text('Buzón de Mensajes', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF0B2545)),
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
    final bool isVip = _subData?['current']?['plan'] == 'sponsored';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isVip ? const Color(0xFFFFC107) : const Color(0xFF0056B3), width: 3), image: DecorationImage(image: ProfileImageHelper.getProfileImageProvider(_userData?['avatar_url']), fit: BoxFit.cover)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¡Hola, Doctor!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0B2545))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF38B6FF), borderRadius: BorderRadius.circular(12)),
                      child: const Text('Doctor', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_userData?['email'] ?? 'doctor@saludnow.com', style: const TextStyle(color: Color(0xFF475569), fontSize: 13), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
