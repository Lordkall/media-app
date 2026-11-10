import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
import '../core/notification_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'clinic_account_screens.dart';
import 'blocked_account_screen.dart';
import 'admin_ads_screen.dart';
import 'health_tab.dart';
import 'select_plan_screen.dart';
import 'payment_pending_screen.dart';
import '../core/distribution_config.dart';
import '../core/health_module_helper.dart';
import '../widgets/floating_ads_overlay.dart';

class MainDoctorScreen extends StatefulWidget {
  const MainDoctorScreen({super.key});

  @override
  State<MainDoctorScreen> createState() => _MainDoctorScreenState();
}

class _MainDoctorScreenState extends State<MainDoctorScreen> {
  bool get _supportsFirebaseMessaging =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  int _currentIndex = 0;
  String? _role;
  String? _browseSpecialty;
  String _browseQuery = '';
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _setupFCM();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkClinicInvite();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkBiometricsPrompt();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationNavigation.consumePending();
    });
    if (_supportsFirebaseMessaging) {
      _openedMessageSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen((message) {
        NotificationNavigation.open(message.data['action_url']?.toString());
      });
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          NotificationNavigation.open(message.data['action_url']?.toString());
        }
      });
    }
  }

  Future<void> _checkBiometricsPrompt() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentToken = prefs.getString('access_token');
      final userId = AuthHelper.getUserIdFromToken(currentToken) ?? 'default';

      final alreadyPrompted =
          prefs.getBool('biometrics_prompt_shown_$userId') ?? false;
      if (alreadyPrompted) return;

      // Mark as prompted so it only asks on first access to main screen
      await prefs.setBool('biometrics_prompt_shown_$userId', true);

      final isAlreadyEnabled =
          prefs.getBool('biometrics_enabled_$userId') ?? false;
      if (isAlreadyEnabled) return;

      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) return;

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.fingerprint, color: Color(0xFF0056B3), size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text('Acceso Biométrico',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: const Text(
            '¿Deseas activar el acceso biométrico (huella o reconocimiento facial) para iniciar sesión de manera más rápida y segura?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Ahora no', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0056B3)),
              child: const Text('Activar'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        try {
          final didAuth = await localAuth.authenticate(
            localizedReason:
                'Confirma tu huella o rostro para activar el acceso biométrico',
            options: const AuthenticationOptions(biometricOnly: true),
          );
          if (didAuth) {
            await prefs.setBool('biometrics_enabled_$userId', true);
            await prefs.setBool('biometrics_enabled', true);
            if (currentToken != null) {
              await prefs.setString('saved_biometric_token', currentToken);
              await prefs.setString('saved_biometric_user_id', userId);
              final userEmail = AuthHelper.getEmailFromToken(currentToken);
              if (userEmail != null) {
                await prefs.setString('logged_username', userEmail);
              }
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Acceso biométrico activado.')),
              );
            }
          }
        } catch (e) {
          debugPrint('Error al autenticar biometría desde el prompt: $e');
        }
      }
    } catch (e) {
      debugPrint('Error en prompt de biometría: $e');
    }
  }

  Future<void> _checkClinicInvite() async {
    final role = await AuthHelper.getRole();
    if (role != 'doctor') return;
    final inviteCode = Uri.base.queryParameters['clinic_invite'];
    if (inviteCode != null && inviteCode.isNotEmpty) {
      try {
        final infoRes = await ApiClient.get('/clinics/invite/$inviteCode');
        if (!mounted) return;
        if (infoRes.statusCode == 200) {
          final info = jsonDecode(infoRes.body);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Invitación de clínica'),
              content: Text('¿Deseas unirte a la clínica "${info['name']}"?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Rechazar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Aceptar')),
              ],
            ),
          );
          if (confirm == true && mounted) {
            final res =
                await ApiClient.post('/clinics/invite/$inviteCode/join', {});
            if (!mounted) return;
            if (res.statusCode == 200) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Solicitud enviada a la clínica.')));
            } else {
              final d = jsonDecode(res.body);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      d['detail']?.toString() ?? 'Error al enviar solicitud')));
            }
          }
        } else {
          final d = jsonDecode(infoRes.body);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(d['detail']?.toString() ?? 'Enlace inválido')));
          }
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al procesar la invitación')));
      }
    }
  }

  Future<void> _setupFCM() async {
    if (!_supportsFirebaseMessaging) return;
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
    try {
      final userRes = await ApiClient.get('/users/me');
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        if (userData['is_blocked'] == true) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const BlockedAccountScreen()),
            (route) => false,
          );
          return;
        }

        final role = userData['role']?.toString();
        if (role == 'doctor' || role == 'clinic') {
          try {
            final subResp = await ApiClient.get('/subscriptions/me');
            if (subResp.statusCode == 200) {
              final subData = jsonDecode(subResp.body);
              if (subData['is_clinic_member'] == true) {
                if (subData['clinic_access_blocked'] == true) {
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const ClinicAccessBlockedScreen()),
                    (route) => false,
                  );
                  return;
                }
              } else {
                final current = subData['current'];
                final pending = subData['pending'];
                final isClinic = role == 'clinic';

                if (current != null) {
                  final graceEnd = DateTime.tryParse(
                      current['grace_end_date']?.toString() ?? '');
                  if (graceEnd != null && DateTime.now().isAfter(graceEnd)) {
                    // Grace period over!
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => isGooglePlayBuild
                            ? PaymentPendingScreen(isClinic: isClinic)
                            : SelectPlanScreen(
                                doctorData: userData, isRenewal: true),
                      ),
                      (route) => false,
                    );
                    return;
                  }
                } else if (pending != null) {
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) =>
                          PaymentPendingScreen(isClinic: isClinic),
                    ),
                    (route) => false,
                  );
                  return;
                } else {
                  // No active subscription and no pending payment: expired!
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => isGooglePlayBuild
                          ? PaymentPendingScreen(isClinic: isClinic)
                          : SelectPlanScreen(
                              doctorData: userData, isRenewal: true),
                    ),
                    (route) => false,
                  );
                  return;
                }
              }
            }
          } catch (_) {}
        }

        final userId = userData['id']?.toString() ?? await AuthHelper.getUserId();
        await HealthModuleHelper.loadForUser(userId);
      }
    } catch (_) {}
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
    _openedMessageSubscription?.cancel();
    super.dispose();
  }

  void _goToSchedule() {
    if (!mounted) return;
    setState(() => _currentIndex = _role == 'clinic' ? 1 : 3);
  }

  void _openAdminDoctorSearch([String query = '']) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: BrowseDoctorsTab(
            initialQuery: query,
            showBackButton: true,
          ),
        ),
      ),
    );
  }

  void _submitHomeSearch(String query) {
    if (_role == 'admin') {
      _openAdminDoctorSearch(query);
      return;
    }
    setState(() {
      _browseSpecialty = null;
      _browseQuery = query;
      _currentIndex = 2;
    });
  }

  List<Widget> get _tabs {
    if (_role == 'clinic') {
      return [
        ClinicHomeTab(
          onCalendar: () => setState(() => _currentIndex = 1),
          onDoctors: () => setState(() => _currentIndex = 3),
          onSearch: () => setState(() => _currentIndex = 2),
          onSearchTap: () => setState(() => _currentIndex = 2),
          onSearchSubmitted: _submitHomeSearch,
          onProfileTap: () => setState(() => _currentIndex = 4),
        ),
        const ClinicCalendarTab(),
        BrowseDoctorsTab(
          initialQuery: _browseQuery,
          onViewSchedule: _goToSchedule,
        ),
        const ClinicDoctorsTab(),
        const ProfileTab(),
      ];
    } else if (_role == 'admin') {
      return [
        AdminHomeTab(
          onProfileTap: () => setState(() => _currentIndex = 3),
          onSearchTap: () => _openAdminDoctorSearch(),
          onSearchSubmitted: (query) => _openAdminDoctorSearch(query),
          onManageAdsTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminAdsScreen(),
            ),
          ),
        ),
        const AdminSubscriptionsTab(),
        const AdminStatsTab(),
        const ProfileTab(),
      ];
    } else if (_role == 'patient') {
      return [
        PatientHomeTab(
          onProfileTap: () => setState(() => _currentIndex = 4),
          onSearchTap: () => setState(() => _currentIndex = 2),
          onSearchSubmitted: _submitHomeSearch,
          onViewSchedule: _goToSchedule,
          onSpecialtyTap: (specialty) => setState(() {
            _browseSpecialty = specialty;
            _browseQuery = '';
            _currentIndex = 2;
          }),
        ),
        AgendarCitaTab(
          onCitaAgendada: () => setState(() => _currentIndex = 0),
          onVerAgenda: () => setState(() => _currentIndex = 3),
        ),
        BrowseDoctorsTab(
          initialSpecialty: _browseSpecialty,
          initialQuery: _browseQuery,
          onViewSchedule: _goToSchedule,
        ),
        const MisCitasTab(),
        const ProfileTab(),
      ];
    } else {
      // doctor
      return [
        DoctorHomeTab(
          onProfileTap: () => setState(() => _currentIndex = 4),
          onCitasHoyTap: () => setState(() => _currentIndex = 3),
          onSearchTap: () => setState(() => _currentIndex = 2),
          onSearchSubmitted: _submitHomeSearch,
          onSpecialtyTap: (specialty) => setState(() {
            _browseSpecialty = specialty;
            _browseQuery = '';
            _currentIndex = 2;
          }),
        ),
        const MiDisponibilidadTab(),
        BrowseDoctorsTab(
          initialQuery: _browseQuery,
          onViewSchedule: _goToSchedule,
        ),
        MisCitasTab(initialDate: caracasNow()),
        const ProfileTab(),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final activeIndex = _currentIndex.clamp(0, tabs.length - 1);

    final scaffold = Scaffold(
      extendBody:
          true, // Importante para que el body vaya por debajo del BottomAppBar transparente
      body: Stack(
        children: [
          tabs[activeIndex],
          // Botón flotante de soporte
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
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .98),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: .16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const navItemCount = 4;
                final compactLayout = constraints.maxWidth < 360;
                final inset = compactLayout ? 6.0 : 12.0;
                final availableWidth = constraints.maxWidth - inset * 2;
                final minimumIdleWidth = compactLayout ? 36.0 : 44.0;
                final selectedWidth = math.min(
                  _role == 'admin' ? 120.0 : 108.0,
                  availableWidth - (navItemCount - 1) * minimumIdleWidth,
                );
                final idleWidth = math.min(
                  compactLayout ? 38.0 : 46.0,
                  (availableWidth - selectedWidth) / (navItemCount - 1),
                );
                final doctorHome = _role == 'doctor' || _role == 'assistant';

                if (_role == 'admin') {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNavItem(Icons.home_rounded, 'Home', 0,
                            selectedWidth, idleWidth, compactLayout),
                        _buildNavItem(Icons.people_alt_outlined, 'Usuarios', 1,
                            selectedWidth, idleWidth, compactLayout),
                        _buildNavItem(Icons.bar_chart_rounded, 'Estadísticas', 2,
                            selectedWidth, idleWidth, compactLayout),
                        _buildNavItem(Icons.person_outline, 'Perfil', 3,
                            selectedWidth, idleWidth, compactLayout),
                      ],
                    ),
                  );
                }

                const profileIndex = 4;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavItem(Icons.home_rounded, 'Home', 0,
                          selectedWidth, idleWidth, compactLayout),
                      _buildNavItem(
                          doctorHome
                              ? Icons.access_time_rounded
                              : Icons.medical_services_outlined,
                          doctorHome ? 'Horario' : 'Agendar',
                          doctorHome ? 1 : 2,
                          selectedWidth,
                          idleWidth,
                          compactLayout),
                      _buildNavItem(
                          Icons.calendar_month_rounded,
                          'Citas',
                          _role == 'clinic' ? 1 : 3,
                          selectedWidth,
                          idleWidth,
                          compactLayout),
                      _buildNavItem(Icons.person_outline, 'Perfil', profileIndex,
                          selectedWidth, idleWidth, compactLayout),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (_role == null || _role == 'admin') {
      return scaffold;
    }

    return Stack(
      children: [
        scaffold,
        Positioned.fill(
          child: FloatingAdsOverlay(key: ValueKey('ads-$_role')),
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index,
      double selectedWidth, double idleWidth, bool compactLayout,
      {bool isHealth = false}) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() {
        _currentIndex = index;
        if (index != 2) _browseSpecialty = null;
      }),
      child: AnimatedContainer(
        duration:
            compactLayout ? Duration.zero : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: isSelected ? selectedWidth : idleWidth,
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: compactLayout ? 6 : 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
                )
              : null,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Semantics(
          button: true,
          label: label,
          selected: isSelected,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keep the icon alone while the pill is still expanding. This
              // prevents the label from wrapping or overflowing for a frame.
              final showLabel = isSelected &&
                  constraints.maxWidth >= (compactLayout ? 60 : 76);
              return ClipRect(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        color:
                            isSelected ? Colors.white : const Color(0xFF475569),
                        size: compactLayout ? 18 : 20),
                    if (showLabel) ...[
                      SizedBox(width: compactLayout ? 4 : 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: compactLayout ? 10 : 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
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
