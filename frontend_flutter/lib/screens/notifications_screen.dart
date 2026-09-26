import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/api_client.dart';
import 'support_messages_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await ApiClient.get('/users/me/notifications');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifications = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0056B3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('No tienes notificaciones.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    IconData icon = Icons.notifications;
                    Color color = Colors.blue;
                    if (n['type'] == 'NEW_DOCTOR') {
                      icon = Icons.person_add;
                      color = Colors.green;
                    } else if (n['type'] == 'NEW_SUBSCRIPTION') {
                      icon = Icons.payment;
                      color = Colors.orange;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        onTap: () {
                          if (n['type'] == 'SUPPORT_MESSAGE') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportMessagesScreen()));
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(n['title'] ?? 'Notificación', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(n['message'] ?? ''),
                        trailing: Text(
                          n['created_at'] != null ? n['created_at'].substring(0, 10) : '',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
