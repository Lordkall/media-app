import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import 'main_doctor_screen.dart';
import 'dart:convert';
import 'dart:ui';
import 'register_screen.dart';
import 'password_recovery_screen.dart';
import 'select_plan_screen.dart';
import 'payment_pending_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    if (token != null) {
      // Instead of navigating right away, we force them to use biometrics
      // Wait for the UI to settle completely to avoid BiometricPromptCompat crash
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
            _loginWithBiometrics();
          } else {
            // Retry if not resumed yet
            Future.delayed(const Duration(milliseconds: 1500), () {
               if (mounted) _loginWithBiometrics();
            });
          }
        });
      });
    }
  }

  Future<void> _loginWithBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('saved_biometric_token');
    
    if (savedToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión con contraseña al menos una vez para usar huella.')),
      );
      return;
    }

    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (canCheckBiometrics || isDeviceSupported) {
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Inicia sesión con tu huella para acceder a Salud Now',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        
        if (didAuthenticate) {
          await prefs.setString('access_token', savedToken);
          _navigateToHome();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu dispositivo no soporta o no tiene configurada biometría.')),
        );
      }
    } catch (e) {
      print('Error de biometría: $e');
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await ApiClient.postForm('/auth/login', {
        'username': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('saved_biometric_token', data['access_token']);
        await prefs.setString('logged_username', _emailController.text.trim());
        
        _navigateToHome();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToHome() async {
    // Check if the user is a doctor and needs a plan
    try {
      final userResponse = await ApiClient.get('/users/me');
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        
        if (userData['role'] == 'doctor') {
          // It's a doctor, check if they have a profile/subscription
          final docResponse = await ApiClient.get('/doctors/me');
          if (docResponse.statusCode == 200) {
             final docData = jsonDecode(docResponse.body);
             // Check their subscription status
             final subResp = await ApiClient.get('/subscriptions/me');
             if (subResp.statusCode == 200) {
               final subData = jsonDecode(subResp.body);
               
               if (subData['current'] != null) {
                 final graceEnd = DateTime.parse(subData['current']['grace_end_date']);
                 if (DateTime.now().isAfter(graceEnd)) {
                   // Grace period over! 
                   if (!mounted) return;
                   Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SelectPlanScreen(doctorData: docData, isRenewal: true)));
                   return;
                 }
                 // Active subscription (within grace period), proceed to home
               } else if (subData['pending'] != null) {
                 // Pending subscription, go to waiting screen
                 if (!mounted) return;
                 Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PaymentPendingScreen()));
                 return;
               } else {
                 // No subscription at all
                 if (!mounted) return;
                 Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SelectPlanScreen(doctorData: docData, isRenewal: false)));
                 return;
               }
             }
          }
        }
      }
    } catch (e) {
      print('Navigation error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainDoctorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0EAFC),
              Color(0xFFCFDEF3),
              Color(0xFFB3C6DF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: const Color(0x50FFFFFF),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: const Color(0x80FFFFFF), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 100,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.medical_services, size: 80, color: Color(0xFF0056B3));
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Inicie sesión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0056B3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ingrese a su cuenta de Salud Now',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Correo Electrónico',
                            filled: true,
                            fillColor: const Color(0x20FFFFFF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0x60FFFFFF)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0x60FFFFFF)),
                            ),
                            prefixIcon: const Icon(Icons.email, color: Color(0xFF0B3C85)),
                            labelStyle: const TextStyle(color: Color(0xFF0B2545)),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Color(0xFF0B2545)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            filled: true,
                            fillColor: const Color(0x20FFFFFF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0x60FFFFFF)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0x60FFFFFF)),
                            ),
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFF0B3C85)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF0B3C85),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            labelStyle: const TextStyle(color: Color(0xFF0B2545)),
                          ),
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Color(0xFF0B2545)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0056B3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: _isLoading 
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 20, 
                                    height: 20, 
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  ),
                                  SizedBox(width: 12),
                                  Text('Ingresando...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              )
                            : const Text('Ingresar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          onPressed: _loginWithBiometrics,
                          icon: const Icon(Icons.fingerprint, size: 50, color: Color(0xFF0056B3)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0x20FFFFFF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  const Text('¿Aún no te has registrado? ', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                                    },
                                    child: const Text('Crear cuenta', style: TextStyle(color: Color(0xFF0056B3), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  const Text('¿Olvidaste tu contraseña? ', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordRecoveryScreen()));
                                    },
                                    child: const Text('Recupérala aquí', style: TextStyle(color: Color(0xFF0056B3), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
