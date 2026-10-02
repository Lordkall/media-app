import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/api_client.dart';
import '../core/auth_helper.dart';
import 'login_screen.dart';
import 'support_chat_screen.dart';

class BlockedAccountScreen extends StatefulWidget {
  const BlockedAccountScreen({super.key});

  @override
  State<BlockedAccountScreen> createState() => _BlockedAccountScreenState();
}

class _BlockedAccountScreenState extends State<BlockedAccountScreen> {
  List<dynamic> _existingAppeals = [];

  @override
  void initState() {
    super.initState();
    _loadExistingAppeals();
  }

  Future<void> _loadExistingAppeals() async {
    try {
      final res = await ApiClient.get('/support/');
      if (res.statusCode == 200 && mounted) {
        final list = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _existingAppeals = list;
        });
      }
    } catch (_) {
    }
  }

  Future<void> _handleLogout() async {
    await AuthHelper.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openAppealDialog() {
    final subjectController = TextEditingController(text: 'Apelación de cuenta bloqueada');
    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: Color(0xFF0056B3)),
                  SizedBox(width: 8),
                  Text('Enviar Apelación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Explica detalladamente la situación al equipo de administración para evaluar la reactivación de tu cuenta.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        labelText: 'Asunto',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Motivo de la apelación',
                        hintText: 'Describe por qué consideras que tu cuenta debe ser restablecida...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final subject = subjectController.text.trim();
                          final message = messageController.text.trim();
                          final messenger = ScaffoldMessenger.of(context);
                          if (subject.isEmpty || message.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Por favor completa todos los campos.')),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          try {
                            final res = await ApiClient.post('/support/', {
                              'subject': subject,
                              'message': message,
                            });
                            if (!mounted) return;
                            if (res.statusCode == 200 || res.statusCode == 201) {
                              Navigator.pop(dialogCtx);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('✓ Tu apelación ha sido enviada al equipo de administración.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadExistingAppeals();
                            } else {
                              final d = jsonDecode(res.body);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(d['detail']?.toString() ?? 'Error al enviar la apelación.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            if (mounted) setDialogState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056B3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0056B3),
          elevation: 0,
          toolbarHeight: 64,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Image.asset(
            'assets/logo_white.png',
            height: 48,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.health_and_safety,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF87171), width: 2),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Color(0xFFDC2626),
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Cuenta Bloqueada',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tu cuenta ha sido bloqueada por incumplimiento de las normas y términos de uso de la comunidad SaludNow.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No tienes acceso al menú principal ni a los servicios de agendamiento. Si consideras que se trata de un error, puedes remitir una apelación a soporte técnico.',
                                style: TextStyle(fontSize: 13, color: Color(0xFF991B1B), height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _openAppealDialog,
                          icon: const Icon(Icons.campaign_outlined, color: Colors.white),
                          label: const Text(
                            'Apelar Bloqueo',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0056B3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.logout, color: Color(0xFF475569)),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (_existingAppeals.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tus apelaciones enviadas:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._existingAppeals.map((ticket) {
                          final isClosed = ticket['status'] == 'Cerrado';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              title: Text(
                                ticket['subject'] ?? 'Apelación',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Text(
                                'Estado: ${ticket['status'] ?? 'Abierto'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isClosed ? Colors.grey : const Color(0xFF0056B3),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF0056B3)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SupportChatScreen(ticket: ticket),
                                  ),
                                ).then((_) => _loadExistingAppeals());
                              },
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
