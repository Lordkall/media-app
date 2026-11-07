import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/auth_helper.dart';
import '../core/chat_time.dart';
import '../widgets/profile_avatar.dart';

class DirectConversationsScreen extends StatefulWidget {
  const DirectConversationsScreen({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  State<DirectConversationsScreen> createState() =>
      _DirectConversationsScreenState();
}

class _DirectConversationsScreenState extends State<DirectConversationsScreen> {
  List<dynamic> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient.get('/conversations');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(
            () => _conversations = jsonDecode(response.body) as List<dynamic>);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar los mensajes.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Mensajes')) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(child: Text('Aún no tienes conversaciones.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(
                          _conversations[index] as Map);
                      final unread =
                          (item['unread_count'] as num?)?.toInt() ?? 0;
                      return Card(
                        child: ListTile(
                          leading: ProfileAvatar(
                            imageUrl: item['other_avatar']?.toString(),
                            size: 44,
                            fallbackRole: 'patient',
                            borderColor: item['other_is_vip'] == true
                                ? const Color(0xFFFFC107)
                                : Colors.transparent,
                            borderWidth:
                                item['other_is_vip'] == true ? 2 : 0,
                          ),
                          title: Text(
                              item['other_name']?.toString() ?? 'Usuario',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            item['conversation_type'] == 'assistant_patient'
                                ? 'Chat con el asistente · ${item['last_message']?.toString().isNotEmpty == true ? item['last_message'] : 'Conversación sobre una cita'}'
                                : item['is_closed'] == true
                                ? 'Conversación cerrada'
                                : (item['last_message']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true
                                    ? item['last_message'].toString()
                                    : 'Inició una conversación sobre una cita'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: unread > 0
                              ? CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Text('$unread',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                )
                              : (item['is_closed'] == true
                                  ? const Icon(Icons.lock_outline,
                                      color: Colors.grey)
                                  : const Icon(Icons.chevron_right)),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DirectChatScreen(conversation: item),
                              ),
                            );
                            _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key, required this.conversation});
  final Map<String, dynamic> conversation;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _isDoctor = false;
  late bool _closed;
  Timer? _refreshTimer;
  int? _userId;

  int get _conversationId => (widget.conversation['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _closed = widget.conversation['is_closed'] == true;
    _initialize();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _loadMessages());
  }

  Future<void> _initialize() async {
    try {
      final role = await AuthHelper.getRole();
      _isDoctor = role == 'doctor' || role == 'assistant';
      final response = await ApiClient.get('/users/me');
      if (response.statusCode == 200) {
        _userId = int.tryParse(
            (jsonDecode(response.body) as Map)['id']?.toString() ?? '');
      }
    } catch (_) {
      // The conversation can still be read if the profile refresh fails.
    }
    if (mounted) setState(() {});
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final response =
          await ApiClient.get('/conversations/$_conversationId/messages');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => _messages = jsonDecode(response.body) as List<dynamic>);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
      // A transient refresh failure should not interrupt an open conversation.
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending || _closed) return;
    setState(() => _sending = true);
    try {
      final response = await ApiClient.post(
        '/conversations/$_conversationId/messages',
        {'body': body},
      );
      if (response.statusCode == 201) {
        _controller.clear();
        await _loadMessages();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No se pudo enviar el mensaje (${response.statusCode}).')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el mensaje.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_closed || _sending) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;

      setState(() => _sending = true);

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final extension = image.name.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final dataUri = 'data:$mimeType;base64,$base64Image';

      final response = await ApiClient.post(
        '/conversations/$_conversationId/messages',
        {'body': dataUri},
      );

      if (response.statusCode == 201) {
        await _loadMessages();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No se pudo enviar la imagen (${response.statusCode}).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al adjuntar imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openImageFullScreen(Uint8List bytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageAttachment(String dataUri, bool mine) {
    try {
      final base64Str = dataUri.split(',').last;
      final bytes = base64Decode(base64Str);
      return GestureDetector(
        onTap: () => _openImageFullScreen(bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Image.memory(
                bytes,
                width: 240,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Error al mostrar imagen',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Ver',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      return const Text(
        'Imagen no disponible',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.red),
      );
    }
  }

  Future<void> _close() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cerrar conversación'),
        content:
            const Text('Ya no se podrán enviar mensajes en esta conversación.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver')),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final response =
        await ApiClient.post('/conversations/$_conversationId/close', {});
    if (!mounted) return;
    if (response.statusCode == 200) {
      setState(() => _closed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversación cerrada.')),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.conversation['other_name']?.toString() ?? 'Conversación';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ProfileAvatar(
              imageUrl: widget.conversation['other_avatar']?.toString(),
              size: 36,
              fallbackRole: 'patient',
              borderColor: widget.conversation['other_is_vip'] == true
                  ? const Color(0xFFFFC107)
                  : Colors.transparent,
              borderWidth:
                  widget.conversation['other_is_vip'] == true ? 2 : 0,
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (_closed)
                  const Text('Cerrada', style: TextStyle(fontSize: 12)),
              ],
            )),
          ],
        ),
        actions: [
          if (_isDoctor && !_closed)
            IconButton(
              onPressed: _close,
              tooltip: 'Cerrar conversación',
              icon: const Icon(Icons.lock_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          Map<String, dynamic>.from(_messages[index] as Map);
                      final mine = _userId != null &&
                          message['sender_user_id'] == _userId;
                      final body = message['body']?.toString() ?? '';
                      final isImage = body.startsWith('data:image/');

                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .78),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: isImage
                              ? const EdgeInsets.all(6)
                              : const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: mine
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0756A4),
                                      Color(0xFF0A3D78)
                                    ],
                                  )
                                : null,
                            color: mine ? null : const Color(0xFFEAF1FA),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: mine
                                  ? const Radius.circular(16)
                                  : const Radius.circular(4),
                              bottomRight: mine
                                  ? const Radius.circular(4)
                                  : const Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isImage)
                                _buildImageAttachment(body, mine)
                              else
                                Text(
                                  body,
                                  style: TextStyle(
                                    color: mine
                                        ? Colors.white
                                        : const Color(0xFF172B4D),
                                    fontSize: 15,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isImage ? 6 : 0),
                                child: Text(
                                  formatChatDateTime(message['created_at']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: mine
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_closed)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Esta conversación está cerrada.'),
            )
          else
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Botón de adjuntar con gradiente
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF0756A4).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _closed || _sending
                              ? null
                              : () => _pickAndSendImage(ImageSource.gallery),
                          child: const Icon(
                            Icons.attach_file_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                              fontSize: 15, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje…',
                            hintStyle: TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón de enviar con gradiente
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0756A4), Color(0xFF0A3D78)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0756A4)
                                .withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _sending ? null : _send,
                          child: Center(
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
