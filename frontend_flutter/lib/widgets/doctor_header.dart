import 'dart:async';
import 'package:flutter/material.dart';
import '../core/auth_helper.dart';
import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/direct_conversations_screen.dart';
import '../screens/assistant_management_screen.dart';
import '../screens/select_plan_screen.dart';
import '../core/api_client.dart';
import 'dart:convert';

class DoctorHeader extends StatefulWidget {
  const DoctorHeader({super.key});

  @override
  State<DoctorHeader> createState() => _DoctorHeaderState();
}

class _DoctorHeaderState extends State<DoctorHeader> {
  int _unreadCount = 0;
  int _unreadMessages = 0;
  bool _isVip = false;
  String? _userRole;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final role = await AuthHelper.getRole();
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }

      final response = await ApiClient.get('/users/me/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> notifs = jsonDecode(response.body);
        int unread = notifs.where((n) => n['is_read'] == false).length;
        if (mounted) {
          setState(() {
            _unreadCount = unread;
          });
        }
      }

      if (role == 'doctor' || role == 'patient') {
        final messageResponse =
            await ApiClient.get('/conversations/unread-count');
        if (messageResponse.statusCode == 200) {
          final data = jsonDecode(messageResponse.body);
          if (mounted) {
            setState(
                () => _unreadMessages = (data['count'] as num?)?.toInt() ?? 0);
          }
        }
      }

      if (role == 'doctor' || role == 'assistant' || role == 'clinic') {
        final subResponse = await ApiClient.get('/subscriptions/me');
        if (subResponse.statusCode == 200) {
          final subData = jsonDecode(subResponse.body);
          final plan =
              subData['current']?['plan']?.toString().toLowerCase() ?? '';
          final isVip = plan == 'sponsored' ||
              plan == 'vip' ||
              plan == 'clinic_vip' ||
              plan.contains('vip') ||
              plan.contains('patrocinado') ||
              subData['is_vip'] == true;
          if (mounted) {
            setState(() {
              _isVip = isVip;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isVip = false;
          });
        }
      }
    } catch (e) {
      // Ignorar en caso de error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/logo_transparent.png',
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Row(
              children: [
                Icon(Icons.favorite, color: Color(0xFF0056B3)),
                SizedBox(width: 8),
                Text('Salud Now',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0056B3))),
              ],
            ),
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications,
                        color: Color(0xFF0056B3), size: 28),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const NotificationsScreen()),
                      );
                      // Mark all as read locally after returning
                      setState(() {
                        _unreadCount = 0;
                      });
                      ApiClient.post('/users/me/notifications/read', {});
                    },
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              if (_userRole == 'doctor' || _userRole == 'patient')
                Stack(
                  children: [
                    IconButton(
                      tooltip: 'Mensajes',
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: Color(0xFF0056B3), size: 25),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const DirectConversationsScreen()),
                        );
                        _fetchUnreadCount();
                      },
                    ),
                    if (_unreadMessages > 0)
                      Positioned(
                        right: 10,
                        top: 9,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                        ),
                      ),
                  ],
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: Color(0xFF0056B3), size: 28),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await AuthHelper.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                          (route) => false);
                    }
                  } else if (value == 'assistant') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const AssistantManagementScreen()));
                  } else if (value == 'stats') {
                    _showDoctorStatsDialog(context);
                  } else if (value == 'stats_locked') {
                    _showVipStatsUpgradeDialog(context);
                  }
                },
                itemBuilder: (BuildContext context) {
                  final isDoctorOrAssistant =
                      _userRole == 'doctor' || _userRole == 'assistant';
                  final canSeeStats =
                      (isDoctorOrAssistant && _isVip) || _userRole == 'clinic';

                  return [
                    if (_userRole == 'doctor' && _isVip)
                      const PopupMenuItem(
                        value: 'assistant',
                        child: Row(
                          children: [
                            Icon(Icons.smart_toy, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('Configurar Asistente',
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    if (canSeeStats)
                      const PopupMenuItem(
                        value: 'stats',
                        child: Row(
                          children: [
                            Icon(Icons.insights, color: Color(0xFF00A896)),
                            SizedBox(width: 8),
                            Text('Estadísticas',
                                style: TextStyle(
                                    color: Color(0xFF0B2545),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    else if (isDoctorOrAssistant)
                      const PopupMenuItem(
                        value: 'stats_locked',
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Text('Estadísticas (VIP)',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Color(0xFF0056B3)),
                          SizedBox(width: 8),
                          Text('Cerrar sesión'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showVipStatsUpgradeDialog(BuildContext context) async {
    Map<String, dynamic>? userData;
    try {
      final res = await ApiClient.get('/users/me');
      if (res.statusCode == 200) {
        userData = jsonDecode(res.body);
      }
    } catch (_) {}

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Función Exclusiva VIP',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'La visualización de estadísticas de citas es un beneficio exclusivo del Plan VIP Patrocinado.\n\nActualiza tu suscripción para acceder a métricas detalladas, impresión de citas y recordatorios automáticos por WhatsApp.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (userData != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SelectPlanScreen(
                      doctorData: userData!,
                      isRenewal: true,
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Mejorar a VIP',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDoctorStatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.insights, color: Color(0xFF00A896), size: 26),
            const SizedBox(width: 8),
            Text(
              _userRole == 'clinic'
                  ? 'Estadísticas de la Clínica'
                  : 'Estadísticas de Citas',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B2545),
              ),
            ),
          ],
        ),
        content: FutureBuilder<dynamic>(
          future: ApiClient.get('/appointments/doctor/stats'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data?.statusCode != 200) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    'No se pudieron cargar las estadísticas.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            final data = jsonDecode(snapshot.data.body);
            final week = data['week_appointments'] ?? 0;
            final month = data['month_appointments'] ?? 0;
            final total = data['total_appointments'] ?? 0;
            final cancelled = data['cancelled_appointments'] ?? 0;
            final today = data['today_appointments'] ?? 0;
            final docCount = data['doctor_count'] ?? 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_userRole == 'clinic') ...[
                  _buildStatItem('Doctores asociados', '$docCount',
                      Icons.medical_services_outlined, const Color(0xFF0056B3)),
                  const SizedBox(height: 10),
                  _buildStatItem('Citas para hoy', '$today', Icons.today,
                      const Color(0xFF00A896)),
                  const SizedBox(height: 10),
                ],
                _buildStatItem('Citas esta semana', '$week', Icons.date_range,
                    const Color(0xFF0056B3)),
                const SizedBox(height: 10),
                _buildStatItem('Citas este mes', '$month', Icons.calendar_month,
                    const Color(0xFF00A896)),
                const SizedBox(height: 10),
                _buildStatItem('Citas totales', '$total', Icons.assignment,
                    const Color(0xFF0B2545)),
                const SizedBox(height: 10),
                _buildStatItem('Citas canceladas', '$cancelled',
                    Icons.cancel_outlined, Colors.redAccent),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            radius: 18,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
