import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../core/api_client.dart';
import 'support_messages_screen.dart';
import '../core/notification_navigation.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _isFetching = false;
  bool _isDeleting = false;
  bool _showAllNotifications = false;
  Timer? _pollingTimer;

  static String _formatRelativeTime(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final parsed = DateTime.parse(rawDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(parsed);

      if (diff.isNegative || diff.inMinutes < 1) {
        return 'hace 1 min';
      } else if (diff.inMinutes < 60) {
        return 'hace ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'hace ${diff.inHours} h';
      } else if (diff.inDays < 365) {
        return 'hace ${diff.inDays} d';
      } else {
        final years = (diff.inDays / 365).floor();
        return 'Hace $years a';
      }
    } catch (_) {
      return rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    }
  }

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

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Eliminar notificaciones',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          '¿Deseas eliminar todas tus notificaciones? Esta acción no se puede deshacer.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancelar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Eliminar todas',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final response = await ApiClient.delete('/users/me/notifications');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _notifications.clear());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notificaciones eliminadas')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron eliminar: ${response.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotifications = _showAllNotifications
        ? _notifications
        : _notifications.take(8).toList();
    final hasMore = _notifications.length > 8 && !_showAllNotifications;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Notificaciones', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0056B3),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              tooltip: 'Eliminar todas las notificaciones',
              onPressed: _isDeleting ? null : _deleteAllNotifications,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_outline_rounded,
                      color: Colors.white),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Text('No tienes notificaciones.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleNotifications.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == visibleNotifications.length && hasMore) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAllNotifications = true;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0056B3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.history_rounded,
                                size: 18, color: Color(0xFF0056B3)),
                            label: Text(
                              'Ver notificaciones anteriores (${_notifications.length - 8} más)',
                              style: const TextStyle(
                                color: Color(0xFF0056B3),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final n = visibleNotifications[index];
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
                    } else if (type == 'water_reminder' ||
                        type == 'health_reminder') {
                      icon = Icons.water_drop_rounded;
                      color = const Color(0xFF0D6EFD);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        onTap: () async {
                          if (type == 'support_message') {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SupportMessagesScreen()));
                          } else {
                            await NotificationNavigation.open(
                              n['action_url']?.toString(),
                              context: context,
                            );
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(n['title'] ?? 'Notificación',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(n['message'] ?? ''),
                        trailing: Text(
                          _formatRelativeTime(n['created_at']?.toString()),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
