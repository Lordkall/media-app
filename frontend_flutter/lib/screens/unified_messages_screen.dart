import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/api_client.dart';
import '../core/auth_helper.dart';
import 'direct_conversations_screen.dart';
import 'support_messages_screen.dart';

class UnifiedMessagesScreen extends StatefulWidget {
  const UnifiedMessagesScreen({super.key});

  @override
  State<UnifiedMessagesScreen> createState() => _UnifiedMessagesScreenState();
}

class _UnifiedMessagesScreenState extends State<UnifiedMessagesScreen> {
  String? _role;
  bool _canDirect = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await AuthHelper.getRole();
    var canDirect = role == 'doctor' || role == 'patient';
    if (role == 'assistant') {
      try {
        final response = await ApiClient.get('/subscriptions/me');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final plan = data['current']?['plan']?.toString().toLowerCase() ?? '';
          canDirect = data['is_vip'] == true ||
              plan == 'sponsored' ||
              plan == 'clinic_vip';
        }
      } catch (_) {}
    }
    if (mounted)
      setState(() {
        _role = role;
        _canDirect = canDirect;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canSupport = _role != 'clinic';
    final tabs = <Tab>[];
    final pages = <Widget>[];
    if (_canDirect) {
      tabs.add(
          const Tab(text: 'Pacientes', icon: Icon(Icons.chat_bubble_outline)));
      pages.add(const DirectConversationsScreen(showAppBar: false));
    }
    if (canSupport) {
      tabs.add(const Tab(text: 'Soporte', icon: Icon(Icons.support_agent)));
      pages.add(const SupportMessagesScreen(showAppBar: false));
    }
    if (pages.length == 1)
      return Scaffold(
          appBar: AppBar(title: const Text('Mensajes')), body: pages.single);
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar:
            AppBar(title: const Text('Mensajes'), bottom: TabBar(tabs: tabs)),
        body: TabBarView(children: pages),
      ),
    );
  }
}
