import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import 'login_screen.dart';

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

class ClinicHomeTab extends StatelessWidget {
  const ClinicHomeTab(
      {super.key, required this.onCalendar, required this.onDoctors});
  final VoidCallback onCalendar;
  final VoidCallback onDoctors;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: ApiClient.get('/users/me'),
        builder: (context, snapshot) {
          final user = snapshot.hasData && snapshot.data!.statusCode == 200
              ? jsonDecode(snapshot.data!.body) as Map<String, dynamic>
              : <String, dynamic>{};
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text('¡Hola, ${user['first_name'] ?? 'Clínica'}!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Panel de administración de la clínica'),
            const SizedBox(height: 24),
            _ClinicActionCard(
              icon: Icons.calendar_month,
              title: 'Calendario',
              subtitle: 'Doctores programados y citas por fecha',
              onTap: onCalendar,
            ),
            _ClinicActionCard(
              icon: Icons.groups,
              title: 'Doctores',
              subtitle: 'Gestiona doctores y solicitudes de afiliación',
              onTap: onDoctors,
            ),
          ]);
        },
      );
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
          Text('Calendario', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Card(
              child: CalendarDatePicker(
            initialDate: _selectedDay,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            currentDate: DateTime.now(),
            onDateChanged: (day) {
              final changedMonth = day.year != _displayedMonth.year ||
                  day.month != _displayedMonth.month;
              setState(() {
                _selectedDay = day;
                _displayedMonth = DateTime(day.year, day.month);
              });
              if (changedMonth) _loadMonth();
            },
            onDisplayedMonthChanged: (month) {
              if (month.year != _displayedMonth.year ||
                  month.month != _displayedMonth.month) {
                setState(
                    () => _displayedMonth = DateTime(month.year, month.month));
                _loadMonth();
              }
            },
          )),
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
                    leading:
                        const CircleAvatar(child: Icon(Icons.medical_services)),
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
          _doctors = jsonDecode(results[0].body) as List<dynamic>;
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
                  onPressed: _shareInvite,
                  tooltip: 'Copiar enlace para invitar',
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
            Tab(text: 'Activos (${_doctors.length})'),
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
                                    leading: const CircleAvatar(
                                        child: Icon(Icons.medical_services)),
                                    title: Text(
                                        'Dr. ${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'),
                                    subtitle: Text(specialties.join(', ')),
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
