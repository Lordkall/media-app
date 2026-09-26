import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '../widgets/doctor_header.dart';
import '../core/api_client.dart';
import '../core/profile_image_helper.dart';
import 'support_messages_screen.dart';

class PatientHomeTab extends StatefulWidget {
  const PatientHomeTab({super.key});

  @override
  State<PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<PatientHomeTab> {
  List<dynamic> _notifications = [];
  List<dynamic> _appointments = [];
  bool _isLoadingNotifications = true;
  bool _isLoadingAppointments = true;
  Map<String, dynamic>? _userData;
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
        if (mounted) {
          final allAppts = jsonDecode(apptResponse.body) as List<dynamic>;
          
          final nowString = DateTime.now().toIso8601String().split('T')[0];
          // Filter out cancelled and past appointments
          var upcoming = allAppts.where((a) {
            final dateStr = a['date'].toString().split('T')[0];
            return a['status'] != 'cancelled' && dateStr.compareTo(nowString) >= 0;
          }).toList();
          
          // Sort by date
          upcoming.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

          setState(() {
            _appointments = upcoming;
            _isLoadingAppointments = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingAppointments = false);
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNotifications = false;
          _isLoadingAppointments = false;
        });
      }
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
                  const Text('Próximas Citas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  if (_isLoadingAppointments)
                    const Center(child: CircularProgressIndicator())
                  else if (_appointments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('No tienes citas próximas.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._appointments.where((a) => a['status'] != 'cancelled').take(2).map((a) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildUpcomingAppointment(
                          a['doctor_name'] ?? 'Dr. Desconocido',
                          a['doctor_specialty'] ?? 'General',
                          '${a['date']} - Turno #${a['turn_number']}',
                          a['status'].toString().toLowerCase(),
                          a['doctor_avatar']
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 12),
                  const Text('Notificaciones Recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  if (_isLoadingNotifications)
                    const Center(child: CircularProgressIndicator())
                  else if (_notifications.isEmpty)
                    const Text('No hay notificaciones recientes.', style: TextStyle(color: Colors.grey))
                  else
                    ..._notifications.take(5).map((n) {
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
                  const SizedBox(height: 24),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              border: Border.all(color: const Color(0xFF0056B3), width: 3), 
              image: DecorationImage(image: ProfileImageHelper.getProfileImageProvider(_userData?['avatar_url']), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¡Hola, Paciente!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0B2545))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF38B6FF), borderRadius: BorderRadius.circular(12)),
                      child: const Text('Paciente', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_userData?['email'] ?? 'paciente@saludnow.com', style: const TextStyle(color: Color(0xFF475569), fontSize: 13), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointment(String doctor, String specialty, String date, String status, String? avatarUrl) {
    String displayStatus = status == 'scheduled' ? 'PROGRAMADA' : status.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(20), // Agrandado
      decoration: BoxDecoration(
        color: const Color(0xFF0056B3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60, // Agrandado
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.white,
              image: DecorationImage(
                image: ProfileImageHelper.getProfileImageProvider(avatarUrl), 
                fit: BoxFit.cover
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(specialty, style: const TextStyle(color: Colors.white70, fontSize: 14), overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                      child: Text(displayStatus, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
