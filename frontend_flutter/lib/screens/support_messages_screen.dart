import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'dart:convert';
import 'support_chat_screen.dart';

class SupportMessagesScreen extends StatefulWidget {
  const SupportMessagesScreen({super.key});

  @override
  State<SupportMessagesScreen> createState() => _SupportMessagesScreenState();
}

class _SupportMessagesScreenState extends State<SupportMessagesScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await ApiClient.get('/support/');
      if (response.statusCode == 200) {
        setState(() {
          _messages = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _closeTicket(int ticketId) async {
    try {
      final response = await ApiClient.patch('/support/$ticketId/close', {});
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cerrado.')));
        _fetchMessages();
      }
    } catch (e) {
      print('Error al cerrar: $e');
    }
  }

  Future<void> _deleteTicket(int ticketId) async {
    try {
      final response = await ApiClient.delete('/support/$ticketId');
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat eliminado.')));
        _fetchMessages();
      }
    } catch (e) {
      print('Error al eliminar: $e');
    }
  }

  void _openChatScreen(Map<dynamic, dynamic> msg) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupportChatScreen(ticket: msg)),
    );
    if (result == true) {
      _fetchMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes de Soporte'),
        backgroundColor: const Color(0xFF0056B3),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)],
          ),
        ),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : _messages.isEmpty 
              ? const Center(child: Text("No hay mensajes.")) 
              : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            final isPending = msg['status'] == 'Pendiente';
            
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          msg['sender'] ?? 'Usuario',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0B2545)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPending ? Colors.orange : (msg['status'] == 'Cerrado' ? Colors.grey : Colors.green),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg['status'] ?? 'Desconocido',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      msg['subject'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0056B3)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      msg['message'] ?? '',
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        msg['date'] ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: (msg['status'] != 'Cerrado') 
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => _closeTicket(msg['id']),
                                icon: const Icon(Icons.close, color: Colors.red),
                                label: const Text('Cerrar Chat', style: TextStyle(color: Colors.red)),
                              ),
                              TextButton.icon(
                                onPressed: () => _openChatScreen(msg),
                                icon: const Icon(Icons.chat, color: Colors.blue),
                                label: const Text('Abrir Chat', style: TextStyle(color: Colors.blue)),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => _deleteTicket(msg['id']),
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: const Text('Borrar', style: TextStyle(color: Colors.red)),
                              ),
                              TextButton.icon(
                                onPressed: () => _openChatScreen(msg),
                                icon: const Icon(Icons.history, color: Colors.grey),
                                label: const Text('Ver Historial', style: TextStyle(color: Colors.grey)),
                              ),
                            ],
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
