import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'dart:convert';

class SupportChatScreen extends StatefulWidget {
  final Map<dynamic, dynamic> ticket;

  const SupportChatScreen({super.key, required this.ticket});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    _isClosed = widget.ticket['status'] == 'Cerrado';
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    // In a real app we'd fetch messages if we don't have them, but the ticket 
    // object already contains `all_messages`.
    final msgs = widget.ticket['all_messages'] as List<dynamic>? ?? [];
    // We assume the first message was from the user (sender). Wait, we need to know who is who.
    // The API doesn't tell us if it's "me" or not directly in all_messages, 
    // but the support endpoint could. For now, since it's a support chat, we assume
    // messages from `sender_id` match the ticket creator? The API only gives us sender_id.
    // Let's just alternate or assume if sender_id == 0 it's me. Actually, we'll fetch /users/me
    final me = jsonDecode((await ApiClient.get('/users/me')).body);
    
    setState(() {
      _chatMessages = msgs.map((m) => {
        'text': m['message'],
        'isMe': m['sender_id'] == me['id'],
        'time': '', // Backend doesn't provide time per message yet
      }).toList();
    });
  }

  Future<void> _closeChat() async {
    try {
      await ApiClient.patch('/support/${widget.ticket['id']}/close', {});
      setState(() {
        _isClosed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cerrado.')));
      Navigator.pop(context, true); // return true to refresh list
    } catch (e) {
      print('Error closing: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isClosed) return;
    
    final text = _messageController.text.trim();
    setState(() {
      _chatMessages.add({'text': text, 'isMe': true, 'time': ''});
      _messageController.clear();
    });
    
    try {
      await ApiClient.post('/support/${widget.ticket['id']}/reply', {'message': text});
    } catch (e) {
      print('Error sending: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF0056B3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.ticket['sender'] ?? 'Usuario',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isClosed)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Cerrar Chat',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cerrar Chat'),
                    content: const Text('¿Estás seguro de que quieres dar por terminada esta conversación?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _closeChat();
                        },
                        child: const Text('Cerrar Chat', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
        backgroundColor: const Color(0xFF0056B3),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE2F1F8),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  if (msg['isSystem'] == true) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(msg['text'], style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
                      ),
                    );
                  }
                  final isMe = msg['isMe'] as bool;
                  return _buildChatBubble(msg['text'], isMe, msg['time']);
                },
              ),
            ),
            if (_isClosed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.grey[300],
                child: const Text(
                  'Este chat ha sido cerrado',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                ),
              )
            else
              _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isMe, String time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0056B3) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF0B2545),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.grey),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_isClosed,
                decoration: InputDecoration(
                  hintText: _isClosed ? 'El chat está cerrado' : 'Escribe un mensaje...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _isClosed ? Colors.grey : const Color(0xFF0056B3),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _isClosed ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
