import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/distribution_config.dart';
import '../widgets/profile_avatar.dart';
import '../core/profile_image_helper.dart';
import '../widgets/doctor_header.dart';
import 'login_screen.dart';
import 'select_plan_screen.dart';
import 'package:table_calendar/table_calendar.dart';
import 'doctor_profile_screen.dart';
import 'clinic_invite_doctor_screen.dart';

class ClinicJoinPendingScreen extends StatelessWidget {
  const ClinicJoinPendingScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ClinicStatusScreen(
        icon: Icons.hourglass_top,
        title: 'Solicitud enviada',
        message:
            'Tu solicitud para unirte a la clínica está pendiente de aprobación. Recibirás una notificación cuando la clínica responda.',
      );
}

class ClinicAccessBlockedScreen extends StatelessWidget {
  const ClinicAccessBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ClinicStatusScreen(
        icon: Icons.lock_outline,
        title: 'Acceso suspendido',
        message:
            'El plan de la clínica está inactivo. Contacta a la clínica para que renueve su suscripción y restablezca el acceso.',
      );
}

class _ClinicStatusScreen extends StatelessWidget {
  const _ClinicStatusScreen(
      {required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 64, color: const Color(0xFF0056B3)),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ]),
          ),
        ),
      );
}

class ClinicHomeTab extends StatefulWidget {
  const ClinicHomeTab(
      {super.key,
      required this.onCalendar,
      required this.onDoctors,
      this.onSearch,
      this.onProfileTap});
  final VoidCallback onCalendar;
  final VoidCallback onDoctors;
  final VoidCallback? onSearch;
  final VoidCallback? onProfileTap;

  @override
  State<ClinicHomeTab> createState() => _ClinicHomeTabState();
}

class _ClinicHomeTabState extends State<ClinicHomeTab> {
  Map<String, dynamic>? _userData;
  List<dynamic> _notifications = [];
  bool _isLoadingNotifications = true;
  bool _isVip = false;
  bool _isSubLoaded = false;
  int? _doctorCount;
  Map<String, dynamic>? _subData;
  Map<String, dynamic>? _clinicStats;

  int _getDaysRemaining() {
    if (_subData == null || _subData!['current'] == null) return 0;
    final endStr = _subData!['current']['end_date'];
    if (endStr == null) return 0;
    try {
      final end = DateTime.parse(endStr.toString());
      final diff = end.difference(DateTime.now()).inDays;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

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

      final subResponse = await ApiClient.get('/subscriptions/me');
      if (subResponse.statusCode == 200) {
        final sub = jsonDecode(subResponse.body) as Map<String, dynamic>;
        final plan = sub['current']?['plan']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _isVip = plan == 'clinic_vip' || plan == 'vip';
            _isSubLoaded = true;
            _subData = sub;
          });
        }
      } else {
        if (mounted) setState(() => _isSubLoaded = true);
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

      final meClinicRes = await ApiClient.get('/clinics/me');
      if (meClinicRes.statusCode == 200) {
        final meClinic = jsonDecode(meClinicRes.body);
        final docRes =
            await ApiClient.get('/clinics/${meClinic['id']}/doctors');
        if (docRes.statusCode == 200) {
          final docs = jsonDecode(docRes.body) as List;
          if (mounted) setState(() => _doctorCount = docs.length);
        }
      }

      final statsRes = await ApiClient.get('/appointments/doctor/stats');
      if (statsRes.statusCode == 200) {
        final stats = jsonDecode(statsRes.body);
        if (mounted) setState(() => _clinicStats = stats);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingNotifications = false;
          _isSubLoaded = true;
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
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  InkWell(
                    onTap: widget.onCalendar,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A896),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
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
                              '${_clinicStats?['today_appointments'] ?? 0}',
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
                  const SizedBox(height: 16),
                  ..._buildRecentNotifications(),
                  const SizedBox(height: 8),
                  const Text('Estadísticas de Citas',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B2545))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Esta semana',
                          value: '${_clinicStats?['week_appointments'] ?? 0}',
                          icon: Icons.date_range,
                          color: const Color(0xFF0056B3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Este mes',
                          value: '${_clinicStats?['month_appointments'] ?? 0}',
                          icon: Icons.calendar_month,
                          color: const Color(0xFF00A896),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Citas totales',
                          value: '${_clinicStats?['total_appointments'] ?? 0}',
                          icon: Icons.assignment,
                          color: const Color(0xFF0B2545),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Canceladas',
                          value:
                              '${_clinicStats?['cancelled_appointments'] ?? 0}',
                          icon: Icons.cancel_outlined,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: widget.onDoctors,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFE2F1F8),
                            radius: 22,
                            child: Icon(Icons.medical_services,
                                color: Color(0xFF0056B3), size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Doctores Asociados',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0B2545))),
                                SizedBox(height: 2),
                                Text('Gestionar plantel médico',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Text(
                            _doctorCount == null ? '...' : '$_doctorCount',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B2545)),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right,
                              color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!isGooglePlayBuild)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_userData != null) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => SelectPlanScreen(
                                    doctorData: _userData!, isRenewal: true)));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0056B3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                            'Renovar o Cambiar Plan (Quedan ${_getDaysRemaining()} días)',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecentNotifications() => [
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
          ..._notifications.take(5).map((n) => Padding(
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
              )),
        const SizedBox(height: 16),
      ];

  Widget _buildProfileSection() {
    if (_userData == null || !_isSubLoaded) {
      return const SizedBox(height: 80);
    }
    final name =
        (_userData?['first_name']?.toString().trim().isNotEmpty ?? false)
            ? _userData!['first_name']
            : 'Clínica';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onProfileTap,
            child: ProfileAvatar(
              imageUrl: _userData?['avatar_url']?.toString(),
              currentUser: true,
              fallbackRole: 'clinic',
              size: 80,
              borderColor:
                  _isVip ? const Color(0xFFD7AF48) : const Color(0xFF0056B3),
              borderWidth: _isVip ? 4 : 3,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¡Hola, $name!',
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
                          color: _isVip
                              ? const Color(0xFFD7AF48)
                              : const Color(0xFF0056B3),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isSubLoaded)
                            const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                          else ...[
                            if (_isVip) ...const [
                              Icon(Icons.star, size: 12, color: Colors.white),
                              SizedBox(width: 4)
                            ],
                            Text(_isVip ? 'VIP' : 'Clínica',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_userData?['email'] ?? '',
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            radius: 18,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClinicCalendarTab extends StatefulWidget {
  const ClinicCalendarTab({super.key});

  @override
  State<ClinicCalendarTab> createState() => _ClinicCalendarTabState();
}

class _ClinicCalendarTabState extends State<ClinicCalendarTab> {
  DateTime _selectedDay = DateTime.now();
  DateTime _displayedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic> _days = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.get(
          '/clinics/me/calendar?year=${_displayedMonth.year}&month=${_displayedMonth.month}');
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw Exception(
            'No se pudo cargar el calendario (${response.statusCode}).');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _days = {
          for (final day in payload['days'] as List<dynamic>)
            day['date'] as String: day as Map<String, dynamic>
        };
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final key =
        '${_selectedDay.year.toString().padLeft(4, '0')}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}';
    final selected = _days[key] as Map<String, dynamic>?;
    final doctors = selected?['doctors'] as List<dynamic>? ?? const [];
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Text('Calendario',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B2545),
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2100),
                focusedDay: _displayedMonth,
                currentDay: DateTime.now(),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  final changedMonth =
                      selectedDay.year != _displayedMonth.year ||
                          selectedDay.month != _displayedMonth.month;
                  setState(() {
                    _selectedDay = selectedDay;
                    _displayedMonth = focusedDay;
                  });
                  if (changedMonth) _loadMonth();
                },
                onPageChanged: (focusedDay) {
                  setState(() => _displayedMonth = focusedDay);
                  _loadMonth();
                },
                availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: Color(0xFF0056B3),
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: const Color(0xFF0056B3).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  dowTextFormatter: (date, locale) {
                    switch (date.weekday) {
                      case 1:
                        return 'L';
                      case 2:
                        return 'M';
                      case 3:
                        return 'X';
                      case 4:
                        return 'J';
                      case 5:
                        return 'V';
                      case 6:
                        return 'S';
                      case 7:
                        return 'D';
                      default:
                        return '';
                    }
                  },
                ),
                calendarBuilders: CalendarBuilders(
                  dowBuilder: (context, day) {
                    final text =
                        ['D', 'L', 'M', 'X', 'J', 'V', 'S'][day.weekday % 7];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: Color(0xFF0056B3), width: 2)),
                      ),
                      child: Center(
                        child: Text(text,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B2545))),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
              'Doctores del ${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
              style: Theme.of(context).textTheme.titleLarge),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (!_loading && _error == null) ...[
            Card(
                child: ListTile(
              leading:
                  const Icon(Icons.event_available, color: Color(0xFF0056B3)),
              title: const Text('Total de citas registradas'),
              trailing: Text('${selected?['appointment_count'] ?? 0}',
                  style: Theme.of(context).textTheme.titleLarge),
            )),
            if (doctors.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No hay doctores programados para esta fecha.'))
            else
              ...doctors.map((item) => Card(
                      child: ListTile(
                    leading: ProfileAvatar(
                        imageUrl: item['profile_picture_url']?.toString(),
                        fallbackRole: 'doctor',
                        size: 40),
                    title: Text(item['name']?.toString() ?? 'Doctor'),
                    subtitle: Text('${item['appointment_count'] ?? 0} citas'),
                  ))),
          ],
        ]);
  }
}

class ClinicDoctorsTab extends StatefulWidget {
  const ClinicDoctorsTab({super.key});

  @override
  State<ClinicDoctorsTab> createState() => _ClinicDoctorsTabState();
}

class _ClinicDoctorsTabState extends State<ClinicDoctorsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);
  List<dynamic> _doctors = [];
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _inviteUrl;
  int? _maxDoctors;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.get('/clinics/me/doctors'),
        ApiClient.get('/clinics/me/doctor-requests'),
      ]);
      if (!mounted) return;
      setState(() {
        if (results[0].statusCode == 200) {
          final data = jsonDecode(results[0].body);
          if (data is Map<String, dynamic>) {
            _doctors = data['doctors'] as List<dynamic>;
            _maxDoctors = data['max_doctors'] as int?;
          } else {
            _doctors = data as List<dynamic>;
          }
        }
        if (results[1].statusCode == 200) {
          _requests = jsonDecode(results[1].body) as List<dynamic>;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(int doctorId, bool approve) async {
    final response = await ApiClient.post(
        '/clinics/me/doctors/$doctorId/${approve ? 'approve' : 'reject'}', {});
    if (!mounted) return;
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(approve ? 'Doctor aprobado.' : 'Solicitud rechazada.')));
      await _load();
    } else {
      var detail = 'No se pudo procesar la solicitud.';
      try {
        detail = jsonDecode(response.body)['detail']?.toString() ?? detail;
      } catch (_) {}
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(detail)));
    }
  }

  Future<void> _removeDoctor(int doctorId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expulsar doctor'),
        content: Text(
            '¿Estás seguro de que deseas expulsar al Dr. $name de tu clínica?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await ApiClient.delete('/clinics/me/doctors/$doctorId');
      if (!mounted) return;
      if (res.statusCode == 200) {
        await _load();
      } else {
        var detail = 'Error desconocido';
        try {
          detail = jsonDecode(res.body)['detail']?.toString() ?? detail;
        } catch (_) {}
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(detail)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _shareInvite() async {
    final response = await ApiClient.get('/clinics/me/invite');
    if (!mounted) return;
    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo generar el enlace de invitación.')));
      return;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['url'].toString();
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    setState(() => _inviteUrl = url);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace de invitación copiado.')));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(
                  child: Text('Doctores',
                      style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const ClinicInviteDoctorScreen()));
                  },
                  tooltip: 'Buscar e invitar doctor',
                  icon: const Icon(Icons.person_add_alt_1)),
              IconButton(
                  onPressed: _load,
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh)),
            ]),
          ),
          if (_inviteUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SelectableText(_inviteUrl!),
            ),
          TabBar(controller: _controller, tabs: [
            Tab(text: 'Solicitudes (${_requests.length})'),
            Tab(
                text:
                    'Activos (${_doctors.length}${_maxDoctors != null ? '/$_maxDoctors' : ''})'),
          ]),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _controller,
                    children: [
                      _requests.isEmpty
                          ? const Center(
                              child: Text('No hay solicitudes pendientes.'))
                          : ListView(
                              children: _requests
                                  .map((item) => _DoctorRequestCard(
                                        item: item,
                                        onApprove: () => _decide(
                                            item['doctor_id'] as int, true),
                                        onReject: () => _decide(
                                            item['doctor_id'] as int, false),
                                      ))
                                  .toList(),
                            ),
                      _doctors.isEmpty
                          ? const Center(
                              child: Text('Aún no hay doctores afiliados.'))
                          : ListView(
                              children: _doctors.map((item) {
                                final specialties =
                                    item['specialties'] as List<dynamic>? ?? [];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  child: ListTile(
                                    onTap: () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  DoctorProfileScreen(
                                                      doctor: item)));
                                    },
                                    leading: ProfileAvatar(
                                      imageUrl: item['avatar_url']?.toString(),
                                      size: 40,
                                      fallbackRole: 'doctor',
                                    ),
                                    title: Text(
                                        'Dr. ${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'),
                                    subtitle: Text(specialties.join(', ')),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _removeDoctor(
                                          item['id'] as int,
                                          '${item['first_name']} ${item['last_name']}'),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
          ),
        ],
      );
}

class _DoctorRequestCard extends StatelessWidget {
  const _DoctorRequestCard(
      {required this.item, required this.onApprove, required this.onReject});
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dr. ${item['first_name'] ?? ''} ${item['last_name'] ?? ''}',
                style: Theme.of(context).textTheme.titleMedium),
            Text(item['email']?.toString() ?? ''),
            Text((item['specialties'] as List<dynamic>? ?? []).join(', ')),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: onReject, child: const Text('Rechazar')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onApprove, child: const Text('Aprobar'))
            ]),
          ])));
}

class _ClinicActionCard extends StatelessWidget {
  const _ClinicActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: Icon(icon, color: const Color(0xFF0056B3)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap));
}
