import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import '../core/api_client.dart';
import 'main_doctor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import 'package:salud_now/screens/payment_pending_screen.dart';

class SelectPlanScreen extends StatefulWidget {
  final Map<String, dynamic> doctorData;
  final bool isRenewal;
  const SelectPlanScreen({super.key, required this.doctorData, this.isRenewal = false});

  @override
  State<SelectPlanScreen> createState() => _SelectPlanScreenState();
}

class _SelectPlanScreenState extends State<SelectPlanScreen> {
  bool _isAnual = false;
  bool _isLoading = true;
  double _bcvRate = 42.5; // fallback
  final TextEditingController _referenceController = TextEditingController();
  String? _screenshotBase64;

  @override
  void initState() {
    super.initState();
    _fetchBcvRate();
  }

  Future<void> _fetchBcvRate() async {
    try {
      final response = await ApiClient.get('/users/bcv-rate');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _bcvRate = (data['rate'] as num).toDouble();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitPlan(String planName, String reference, double amount, String? screenshot) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.post('/subscriptions/renew', {
        'plan_name': planName,
        'billing_cycle': _isAnual ? 'Anual' : 'Mensual',
        'reference_number': reference,
        'amount_bs': amount,
        if (screenshot != null) 'screenshot_base64': screenshot,
      });
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        if (widget.isRenewal) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Renovación en proceso'),
              content: const Text('Tu pago ha sido reportado y está pendiente de aprobación. Como renovaste a tiempo, mantendrás tu acceso activo.'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back from SelectPlanScreen to Profile/Home
                  },
                  child: const Text('Aceptar'),
                )
              ],
            ),
          );
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PaymentPendingScreen()));
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar la solicitud.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(StateSetter setStateDialog) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setStateDialog(() {
        _screenshotBase64 = base64Encode(bytes);
      });
    }
  }

  void _showPaymentDialog(String planCode, String planTitle, String priceBs) {
    _referenceController.clear();
    _screenshotBase64 = null;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Pago de $planTitle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monto a Pagar:', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 22, color: Colors.blue),
                      tooltip: 'Copiar Datos',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: 'Banco de Venezuela\nCI: V-12345678\nTel: 0412-1234567\nMonto: Bs $priceBs'));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos copiados al portapapeles')));
                      },
                    ),
                  ],
                ),
                Text('Bs $priceBs', style: const TextStyle(fontSize: 18, color: Colors.blue)),
                const SizedBox(height: 16),
                const Text('Datos de Pago Móvil', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('Banco de Venezuela\nCI: V-12345678\nTel: 0412-1234567'),
                const SizedBox(height: 16),
                TextField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Referencia',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(setStateDialog), 
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Subir Capture (Opcional)'),
                ),
                if (_screenshotBase64 != null) ...[
                  const SizedBox(height: 8),
                  const Text('✅ Captura adjuntada', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                if (_referenceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes ingresar el número de referencia')));
                  return;
                }
                Navigator.pop(context);
                
                double amount = double.tryParse(priceBs.replaceAll(',', '')) ?? 0.0;
                _submitPlan(planCode, _referenceController.text.trim(), amount, _screenshotBase64);
              },
              child: const Text('Confirmar Pago', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current BCV rate fetched from API
    final double bcvRate = _bcvRate; 
    
    final isClinic = widget.doctorData['role'] == 'clinic';
    
    final basicPrice = _isAnual ? (isClinic ? 1500 : 200) : (isClinic ? 150 : 20);
    final vipPrice = _isAnual ? (isClinic ? 2500 : 400) : (isClinic ? 250 : 40);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona tu Plan', style: TextStyle(color: Colors.white)), 
        backgroundColor: const Color(0xFF0B2545)
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3), Color(0xFFB3C6DF)],
          ),
        ),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Elige tu nivel de suscripción', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0B2545)), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Mensual'),
                    Switch(
                      value: _isAnual,
                      onChanged: (val) => setState(() => _isAnual = val),
                    ),
                    const Text('Anual (Ahorra 2 meses)'),
                  ],
                ),
                const SizedBox(height: 16),
                if (isClinic) ...[
                  _buildPlanCard(
                    'Clínica Básico', 
                    basicPrice.toString(), 
                    (basicPrice * bcvRate).toStringAsFixed(2),
                    'Registro de clínica en la plataforma\n• Máximo 10 doctores asociados\n• Recepción de citas\n• Soporte estándar',
                    'clinic_basic'
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    'Clínica VIP', 
                    vipPrice.toString(), 
                    (vipPrice * bcvRate).toStringAsFixed(2),
                    'Todos los beneficios VIP de clínica\n• Máximo 15 doctores asociados\n• Posicionamiento VIP\n• Soporte prioritario y reportes',
                    'clinic_vip',
                    isVip: true
                  ),
                ] else ...[
                  _buildPlanCard(
                    'Plan Básico', 
                    basicPrice.toString(), 
                    (basicPrice * bcvRate).toStringAsFixed(2),
                    'Presencia médica y posicionamiento destacado\n• Perfil médico verificado\n• Insignia Doctor Destacado\n• Recepción ilimitada de citas',
                    'basic'
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    'Plan VIP Patrocinado', 
                    vipPrice.toString(), 
                    (vipPrice * bcvRate).toStringAsFixed(2),
                    'Prioridad absoluta TOP #1\n• Banner destacado\n• Recordatorios automáticos\n• Soporte 24/7',
                    'sponsored',
                    isVip: true
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(String title, String priceUsd, String priceBs, String features, String planCode, {bool isVip = false}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isVip ? Colors.amber : Colors.blue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('\$$priceUsd', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isVip ? Colors.amber[800] : Colors.blue[800])),
            Text('Bs $priceBs (Tasa BCV)', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Text(features, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showPaymentDialog(planCode, title, priceBs),
              style: ElevatedButton.styleFrom(backgroundColor: isVip ? Colors.amber[700] : Colors.blue[700]),
              child: const Text('Seleccionar y Pagar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
