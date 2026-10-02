import 'package:flutter/material.dart';
import 'dart:convert';
import '../widgets/doctor_header.dart';
import '../widgets/profile_avatar.dart';
import '../core/api_client.dart';
import '../core/profile_image_helper.dart';
import '../models/ve_catalogs.dart';
import 'support_messages_screen.dart';

class PatientHomeTab extends StatefulWidget {
  const PatientHomeTab({super.key, this.onProfileTap});
  final VoidCallback? onProfileTap;

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
        final user = Map<String, dynamic>.from(jsonDecode(userResponse.body));
        ProfileImageHelper.updateCurrentUserAvatar(
            user['avatar_url']?.toString());
        if (mounted) setState(() => _userData = user);
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

          final nowString = caracasNow().toIso8601String().split('T')[0];
          // Filter out cancelled and past appointments
          var upcoming = allAppts.where((a) {
            final dateStr = a['date'].toString().split('T')[0];
            return a['status'] != 'cancelled' &&
                dateStr.compareTo(nowString) >= 0;
          }).toList();

          // Sort by date
          upcoming.sort(
              (a, b) => a['date'].toString().compareTo(b['date'].toString()));

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
                  const Text('Próximas Citas',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  if (_isLoadingAppointments)
                    const Center(child: CircularProgressIndicator())
                  else if (_appointments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('No tienes citas próximas.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._appointments
                        .where((a) => a['status'] != 'cancelled')
                        .take(2)
                        .map((a) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildUpcomingAppointment(a),
                      );
                    }),
                  const SizedBox(height: 12),
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
                    ..._notifications.take(5).map((n) {
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
                    }),
                  const SizedBox(height: 24),
                  ListTile(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SupportMessagesScreen()));
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white.withValues(alpha: 0.5),
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
                fallbackRole: 'patient',
                size: 80,
                borderColor: const Color(0xFF0056B3),
                borderWidth: 3),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '¡Hola, ${(_userData?['first_name']?.toString().trim().isNotEmpty ?? false) ? _userData!['first_name'] : 'Paciente'}!',
                    style: const TextStyle(
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
                      child: const Text('Paciente',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            _userData?['email'] ?? 'paciente@saludnow.com',
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

    void _showAppointmentDetails(Map<String, dynamic> appt) {
    final doctor = appt['doctor_name'] ?? 'Dr. Desconocido';
    final specialty = appt['doctor_specialty'] ?? 'General';
    final date = appt['date']?.toString() ?? '';
    final time = appt['time_block']?.toString() ?? 'Hora pendiente';
    final turn = appt['turn_number']?.toString() ?? '-';
    final location = appt['doctor_location']?.toString() ?? '';
    final reason = appt['appointment_reason']?.toString() ?? 'Consulta Médica';
    final status = (appt['status'] ?? 'scheduled').toString().toLowerCase();
    final avatarUrl = appt['doctor_avatar'] as String?;
    final String displayStatus = status == 'scheduled' ? 'PROGRAMADA' : status.toUpperCase();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      ProfileAvatar(imageUrl: avatarUrl, size: 84, fallbackRole: 'doctor'),
                      const SizedBox(height: 12),
                      Text(
                        doctor,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF0056B3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: status == 'scheduled' ? Colors.green.shade600 : Colors.blueGrey,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          displayStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F1F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF0056B3).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, color: Color(0xFF0056B3), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TURNO ASIGNADO',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0056B3))),
                            Text('Turno #$turn',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.calendar_today, 'Fecha', date),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.access_time, 'Hora estimada', time),
                if (location.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.location_on, 'Ubicación / Consultorio', location),
                ],
                if (reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.medical_services_outlined, 'Motivo de consulta', reason),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0056B3)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF0B2545), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingAppointment(Map<String, dynamic> appt) {
    final doctor = appt['doctor_name'] ?? 'Dr. Desconocido';
    final specialty = appt['doctor_specialty'] ?? 'General';
    final date = '${appt['date']} · ${appt['time_block'] ?? 'Hora pendiente'} · Turno #${appt['turn_number']}';
    final location = appt['doctor_location']?.toString() ?? '';
    final status = (appt['status'] ?? 'scheduled').toString().toLowerCase();
    final avatarUrl = appt['doctor_avatar'] as String?;
    final String displayStatus = status == 'scheduled' ? 'PROGRAMADA' : status.toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showAppointmentDetails(appt),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0056B3),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
            ],
          ),
          child: Row(
            children: [
              ProfileAvatar(imageUrl: avatarUrl, size: 60, fallbackRole: 'doctor'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctor,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(specialty,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                                overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(displayStatus,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 14, color: Colors.white70),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(date,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (location.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: Colors.white70),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(location,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
