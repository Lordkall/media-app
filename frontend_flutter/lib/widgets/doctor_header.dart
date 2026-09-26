import 'package:flutter/material.dart';
import '../core/auth_helper.dart';
import '../screens/login_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/assistant_management_screen.dart';
import '../core/api_client.dart';
import 'dart:convert';

class DoctorHeader extends StatefulWidget {
  const DoctorHeader({super.key});

  @override
  State<DoctorHeader> createState() => _DoctorHeaderState();
}

class _DoctorHeaderState extends State<DoctorHeader> {
  int _unreadCount = 0;
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
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
      
      final subResponse = await ApiClient.get('/subscriptions/me');
      if (subResponse.statusCode == 200) {
        final subData = jsonDecode(subResponse.body);
        if (mounted) {
          setState(() {
            _isVip = subData['current']?['plan'] == 'sponsored';
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
          Row(
            children: [
              Image.asset(
                'assets/logo.png',
                height: 40,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.favorite, color: Color(0xFF0056B3)),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Salud Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0056B3))),
                  Text('Plataforma Médica', style: TextStyle(fontSize: 10, color: Color(0xFF38B6FF))),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Color(0xFF0056B3), size: 28),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF0056B3), size: 28),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await AuthHelper.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                    }
                  } else if (value == 'assistant') {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistantManagementScreen()));
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    if (_isVip)
                      const PopupMenuItem(
                        value: 'assistant',
                        child: Row(
                          children: [
                            Icon(Icons.smart_toy, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('Configurar Asistente', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
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
}
