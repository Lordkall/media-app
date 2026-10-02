import 'package:flutter/material.dart';
import 'dart:async';
import '../core/api_client.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class SupportChatScreen extends StatefulWidget {
  final Map<dynamic, dynamic> ticket;

  const SupportChatScreen({super.key, required this.ticket});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isClosed = false;
  bool _isLoadingMessages = false;
  int? _currentUserId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _isClosed = widget.ticket['status'] == 'Cerrado';
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_isLoadingMessages || !mounted) return;
    _isLoadingMessages = true;
    try {
      if (_currentUserId == null) {
        final userResponse = await ApiClient.get('/users/me');
        if (userResponse.statusCode != 200) return;
        final me = jsonDecode(userResponse.body) as Map<String, dynamic>;
        _currentUserId = me['id'] as int;
      }
      final response =
          await ApiClient.get('/support/${widget.ticket['id']}/messages');
      if (response.statusCode != 200 || !mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final messages = List<dynamic>.from(data['messages'] as List);
      setState(() {
        _chatMessages = messages
            .map((message) => {
                  'text': message['message']?.toString() ?? '',
                  'isMe': message['sender_id'] == _currentUserId,
                  'time': '',
                })
            .toList();
        _isClosed = data['status'] == 'Cerrado';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      debugPrint('Could not refresh support chat: $e');
    } finally {
      _isLoadingMessages = false;
    }
  }

  Future<void> _closeChat() async {
    try {
      final response =
          await ApiClient.patch('/support/${widget.ticket['id']}/close', {});
      if (response.statusCode != 200) {
        throw Exception('No se pudo cerrar el chat (${response.statusCode})');
      }
      if (!mounted) return;
      setState(() {
        _isClosed = true;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chat cerrado.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo cerrar el chat: $e')));
      }
    }
  }

  bool _isSending = false;

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isClosed || _isSending) return;
    
    setState(() {
      _isSending = true;
    });

    final text = _messageController.text.trim();
    try {
      final response = await ApiClient.post(
          '/support/${widget.ticket['id']}/reply', {'message': text});
      if (response.statusCode != 200) {
        throw Exception('No se pudo enviar el mensaje');
      }
      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar el mensaje: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
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
                    content: const Text(
                        '¿Estás seguro de que quieres dar por terminada esta conversación?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _closeChat();
                        },
                        child: const Text('Cerrar Chat',
                            style: TextStyle(color: Colors.white)),
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
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
                  if (msg['isSystem'] == true) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(msg['text'],
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontStyle: FontStyle.italic)),
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
                  style: TextStyle(
                      color: Colors.black54, fontWeight: FontWeight.bold),
                ),
              )
            else
              _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  
  Future<void> _pickAndSendImage() async {
    if (_isClosed || _isSending) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;
      
      setState(() {
        _isSending = true;
      });
      
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final extension = image.name.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final dataUri = 'data:;base64,';
      
      final response = await ApiClient.post(
          '/support//reply', {'message': dataUri});
      if (response.statusCode != 200) {
        throw Exception('No se pudo enviar la imagen');
      }
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar imagen: ')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
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
            bottomLeft:
                isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            text.startsWith('data:image/')
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(text.split(',').last),
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  )
                : Text(
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
              onPressed: _isClosed ? null : _pickAndSendImage,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_isClosed,
                decoration: InputDecoration(
                  hintText: _isClosed
                      ? 'El chat está cerrado'
                      : 'Escribe un mensaje...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor:
                  _isClosed ? Colors.grey : const Color(0xFF0056B3),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : IconButton(
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
