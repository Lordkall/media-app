import 'package:flutter/material.dart';
import 'dart:async';
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
  bool _isFetching = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchNotifications();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    if (_isFetching) return;
    _isFetching = true;
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
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Notificaciones', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0056B3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Text('No tienes notificaciones.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    final type = n['type']?.toString().toLowerCase();
                    IconData icon = Icons.notifications;
                    Color color = Colors.blue;
                    if (type == 'doctor_registered') {
                      icon = Icons.person_add;
                      color = Colors.green;
                    } else if (type == 'new_subscription') {
                      icon = Icons.payment;
                      color = Colors.orange;
                    } else if (type == 'support_message') {
                      icon = Icons.support_agent;
                      color = Colors.deepPurple;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        onTap: () {
                          if (type == 'support_message') {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SupportMessagesScreen()));
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(n['title'] ?? 'Notificación',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(n['message'] ?? ''),
                        trailing: Text(
                          n['created_at'] != null
                              ? n['created_at'].substring(0, 10)
                              : '',
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
