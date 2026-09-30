import 'package:flutter/material.dart';
import 'package:salud_now/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentPendingScreen extends StatelessWidget {
  const PaymentPendingScreen({super.key, this.isClinic = false});
  final bool isClinic;

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            isClinic
                ? 'Plan de clínica en verificación'
                : 'Cuenta en Verificación',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0B2545),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3), Color(0xFFB3C6DF)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_top,
                        size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    Text(
                      isClinic
                          ? 'El pago de la clínica está siendo procesado'
                          : 'Su pago está siendo procesado',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isClinic
                          ? 'La cuenta de la clínica y sus funciones estarán disponibles cuando el administrador verifique el pago.'
                          : 'Pronto su cuenta será activada una vez que el administrador verifique su pago.',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text('Cerrar Sesión',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
