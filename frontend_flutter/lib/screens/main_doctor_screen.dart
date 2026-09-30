import 'dart:async';
import 'package:flutter/material.dart';
import 'patient_home_tab.dart';
import 'doctor_home_tab.dart';
import 'admin_home_tab.dart';
import 'profile_tab.dart';
import 'browse_doctors_tab.dart';
import 'admin_subscriptions_tab.dart';
import 'admin_stats_tab.dart';
import 'agendar_cita_tab.dart';
import 'mi_disponibilidad_tab.dart';
import 'mis_citas_tab.dart';
import '../core/auth_helper.dart';
import '../core/api_client.dart';
import '../models/ve_catalogs.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/local_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'clinic_account_screens.dart';

class MainDoctorScreen extends StatefulWidget {
  const MainDoctorScreen({super.key});

  @override
  State<MainDoctorScreen> createState() => _MainDoctorScreenState();
}

class _MainDoctorScreenState extends State<MainDoctorScreen> {
  int _currentIndex = 0;
  String? _role;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!permissionGranted) {
        debugPrint('Push notifications are not authorized on this device.');
        return;
      }

      _tokenSubscription = messaging.onTokenRefresh.listen(_saveFcmToken);
      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        LocalNotificationService.showRemoteMessage(message).catchError((error) {
          debugPrint('Could not display the foreground notification: $error');
        });
        final title = message.notification?.title ?? 'Salud Now';
        final body =
            message.notification?.body ?? 'Tienes una notificación nueva.';
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$title: $body')));
        }
      });

      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM device token acquired. Saving it for this user.');
        await _saveFcmToken(token);
      } else {
        debugPrint('Firebase Messaging returned an empty device token.');
      }
    } catch (error, stackTrace) {
      debugPrint(
          'Could not register this device for push notifications: $error\n$stackTrace');
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      final response = await ApiClient.put('/users/me', {'fcm_token': token});
      if (response.statusCode != 200) {
        debugPrint(
            'FCM token registration failed: ${response.statusCode} ${response.body}');
      }
    } catch (error) {
      debugPrint('Could not save FCM token: $error');
    }
  }

  Future<void> _loadRole() async {
    final role = await AuthHelper.getRole();
    if (!mounted) return;
    setState(() {
      _role = role;
    });
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  List<Widget> get _tabs {
    if (_role == 'clinic') {
      return [
        ClinicHomeTab(
          onCalendar: () => setState(() => _currentIndex = 1),
          onDoctors: () => setState(() => _currentIndex = 3),
        ),
        const ClinicCalendarTab(),
        const SizedBox.shrink(),
        const ClinicDoctorsTab(),
        const ProfileTab(),
      ];
    } else if (_role == 'admin') {
      return [
        AdminHomeTab(onProfileTap: () => setState(() => _currentIndex = 4)),
        const AdminSubscriptionsTab(),
        const BrowseDoctorsTab(),
        const AdminStatsTab(),
        const ProfileTab(),
      ];
    } else if (_role == 'patient') {
      return [
        PatientHomeTab(onProfileTap: () => setState(() => _currentIndex = 4)),
        AgendarCitaTab(onCitaAgendada: () {
          setState(() {
            _currentIndex = 0;
          });
        }),
        const BrowseDoctorsTab(),
        const MisCitasTab(),
        const ProfileTab(),
      ];
    } else {
      // doctor
      return [
        DoctorHomeTab(
          onProfileTap: () => setState(() => _currentIndex = 4),
          onCitasHoyTap: () => setState(() => _currentIndex = 3),
        ),
        const MiDisponibilidadTab(),
        const BrowseDoctorsTab(),
        MisCitasTab(initialDate: caracasNow()),
        const ProfileTab(),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody:
          true, // Importante para que el body vaya por debajo del BottomAppBar transparente
      body: Stack(
        children: [
          _tabs[_currentIndex],
          // Botón flotante de soporte
          if (_role != 'admin')
            Positioned(
              bottom: 90,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'supportFAB',
                backgroundColor: const Color(0xFF0056B3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                onPressed: () {
                  _showSupportDialog(context);
                },
                child: const Icon(Icons.support_agent, color: Colors.white),
              ),
            )
        ],
      ),
      floatingActionButton: _role == 'clinic'
          ? null
          : FloatingActionButton(
              heroTag: 'searchFAB',
              backgroundColor: const Color(0xFF0056B3),
              shape: const CircleBorder(),
              onPressed: () {
                setState(() {
                  _currentIndex = 2;
                });
              },
              child: const Icon(Icons.search, color: Colors.white, size: 28),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              if (_role == 'clinic') ...[
                _buildNavItem(Icons.calendar_month, 'Calendario', 1),
                const SizedBox(width: 8),
                _buildNavItem(Icons.groups, 'Doctores', 3),
              ] else if (_role == 'admin') ...[
                _buildNavItem(Icons.card_membership, 'Suscripción', 1),
                const SizedBox(width: 48),
                _buildNavItem(Icons.bar_chart, 'Estadísticas', 3),
              ] else if (_role == 'patient') ...[
                _buildNavItem(Icons.calendar_month, 'Agendar', 1),
                const SizedBox(width: 48),
                _buildNavItem(Icons.medical_information, 'Citas', 3),
              ] else ...[
                // doctor
                _buildNavItem(Icons.schedule, 'Horario', 1),
                const SizedBox(width: 48),
                _buildNavItem(Icons.book, 'Citas', 3),
              ],
              _buildNavItem(Icons.person_outline, 'Perfil', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color =
        isSelected ? const Color(0xFF0056B3) : const Color(0xFF475569);

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24), // Tamaño fijo para que no crezcan
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    final asuntoController = TextEditingController();
    final mensajeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.support_agent, color: Color(0xFF0056B3)),
              SizedBox(width: 8),
              Text('Soporte Técnico',
                  style: TextStyle(fontSize: 18, color: Color(0xFF0B2545))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: asuntoController,
                decoration: const InputDecoration(
                    labelText: 'Asunto', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mensajeController,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Mensaje', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                final subject = asuntoController.text.trim();
                final msg = mensajeController.text.trim();
                if (subject.isEmpty || msg.isEmpty) return;

                try {
                  final response = await ApiClient.post(
                      '/support/', {'subject': subject, 'message': msg});
                  if (response.statusCode == 200) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Mensaje enviado al administrador.')));
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Error al enviar el mensaje.')));
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056B3)),
              child:
                  const Text('Enviar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
