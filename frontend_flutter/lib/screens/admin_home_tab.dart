import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import '../widgets/doctor_header.dart'; // We can reuse the header for now
import '../core/profile_image_helper.dart';
import '../core/api_client.dart';
import 'support_messages_screen.dart';

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  String? _imagePath;
  List<dynamic> _notifications = [];
  bool _isLoadingNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await ApiClient.get('/users/me/notifications');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifications = jsonDecode(response.body);
            _isLoadingNotifications = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingNotifications = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNotifications = false);
    }
  }

  Future<void> _loadImage() async {
    final path = await ProfileImageHelper.getImagePath();
    if (path != null && mounted) {
      setState(() {
        _imagePath = path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE0EAFC),
            Color(0xFFCFDEF3),
            Color(0xFFB3C6DF),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DoctorHeader(), // Adapts perfectly as it shows the top bar
            const SizedBox(height: 16),
            _buildProfileSection(),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Menú principal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B2545),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const Text(
                    'Notificaciones Recientes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingNotifications)
                    const Center(child: CircularProgressIndicator())
                  else if (_notifications.isEmpty)
                    const Text('No hay notificaciones recientes.', style: TextStyle(color: Colors.grey))
                  else
                    ..._notifications.take(5).map((n) {
                      IconData icon;
                      Color color;
                      if (n['type'] == 'NEW_DOCTOR') {
                        icon = Icons.person_add;
                        color = Colors.green;
                      } else if (n['type'] == 'NEW_SUBSCRIPTION') {
                        icon = Icons.payment;
                        color = Colors.orange;
                      } else {
                        icon = Icons.notifications;
                        color = Colors.blue;
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildNotificationCard(
                          context,
                          title: n['title'] ?? 'Notificación',
                          message: n['message'] ?? '',
                          time: n['created_at'] != null ? n['created_at'].substring(0, 10) : '',
                          icon: icon,
                          color: color,
                          notification: n,
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 24),
                  const Text(
                    'Accesos Directos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SupportMessagesScreen()),
                      );
                    },
                    child: _buildMenuCard(
                      context,
                      title: 'Mensajes de Soporte',
                      subtitle: 'Gestiona y responde tickets de usuarios',
                      iconData: Icons.support_agent,
                    ),
                  ),
                  const SizedBox(height: 80), // Para el padding del bottom nav
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0056B3), width: 3),
              color: Colors.grey[200],
              image: _imagePath != null
                  ? DecorationImage(
                      image: FileImage(File(_imagePath!)),
                      fit: BoxFit.cover,
                    )
                  : DecorationImage(
                      image: ProfileImageHelper.getProfileImageProvider(null),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Hola, Administrador!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0B2545),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38B6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Administrador',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'admin@saludnow.com',
                        style: TextStyle(color: Color(0xFF475569), fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePaymentAction(int subId, String action) async {
    try {
      final response = await ApiClient.post('/admin/subscriptions/$subId/$action', {});
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pago ${action == "approve" ? "validado" : "rechazado"} correctamente')));
        _fetchNotifications();
      }
    } catch (e) {
      print('Error en accion de pago: $e');
    }
  }

  void _showScreenshotDialog(BuildContext context, String base64Image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Comprobante', style: TextStyle(fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
            Flexible(
              child: Image.memory(
                base64Decode(base64Image),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, {required String title, required String message, required String time, required IconData icon, required Color color, required Map<String, dynamic> notification}) {
    final paymentDetails = notification['payment_details'];
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B2545)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (paymentDetails != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monto: ${paymentDetails['amount_bs'] ?? 'N/A'} Bs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Referencia: ${paymentDetails['reference_number'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)),
                  if (paymentDetails['screenshot_base64'] != null)
                    TextButton.icon(
                      onPressed: () => _showScreenshotDialog(context, paymentDetails['screenshot_base64']),
                      icon: const Icon(Icons.image, size: 16),
                      label: const Text('Ver captura', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handlePaymentAction(paymentDetails['sub_id'], 'approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Validar pago', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handlePaymentAction(paymentDetails['sub_id'], 'reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text('Rechazar', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required String title, required String subtitle, required IconData iconData}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: const Color(0xFF38B6FF), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2545),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF475569)),
            ],
          ),
        ),
      ),
    );
  }
}
