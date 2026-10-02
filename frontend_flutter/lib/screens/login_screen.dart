import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import '../core/api_client.dart';
import '../core/profile_image_helper.dart';
import 'main_doctor_screen.dart';
import 'dart:convert';
import 'dart:ui';
import 'register_screen.dart';
import 'password_recovery_screen.dart';
import 'select_plan_screen.dart';
import 'payment_pending_screen.dart';
import 'clinic_account_screens.dart';
import '../widgets/web_footer.dart';
import '../widgets/web_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final Uri _latestReleasesUri = Uri.parse(
      'https://github.com/Lordkall/media-app/releases/download/saludnow-247-1/app-release.apk');

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _emailShowsMask = false;
  bool _passwordShowsMask = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  String? _clinicInviteCode;

  Future<void> _openLatestRelease() async {
    final opened = await launchUrl(
      _latestReleasesUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo abrir la página de descarga.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    _checkSavedLogin();
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Error al obtener el link inicial: $e");
    }
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.queryParameters.containsKey('clinic_invite')) {
      setState(() {
        _clinicInviteCode = uri.queryParameters['clinic_invite'];
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final savedEmail = prefs.getString('logged_username');
    if (kIsWeb) {
      // Web has no biometric sign-in: never render the mobile masked
      // credential placeholders on the browser login form.
      await prefs.remove('saved_biometric_token');
      await prefs.remove('logged_username');
      if (mounted) {
        setState(() {
          _emailController.clear();
          _passwordController.clear();
          _emailShowsMask = false;
          _passwordShowsMask = false;
          _obscurePassword = true;
        });
      }
    } else if (token != null &&
        savedEmail != null &&
        savedEmail.isNotEmpty &&
        mounted) {
      setState(() {
        _emailController.text = _maskEmail(savedEmail);
        _emailShowsMask = true;
        _passwordController.text = '********';
        _passwordShowsMask = true;
        _obscurePassword = false;
      });
    }

    if (token != null) {
      if (kIsWeb) {
        _navigateToHome();
        return;
      }
      // Instead of navigating right away, we force them to use biometrics
      // Wait for the UI to settle completely to avoid BiometricPromptCompat crash
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed) {
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

  String _maskEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex < 0) {
      final visibleCount = email.length < 3 ? email.length : 3;
      final maskedCount = (email.length - visibleCount).clamp(3, 32).toInt();
      return '${email.substring(0, visibleCount)}${List.filled(maskedCount, '*').join()}';
    }
    final localPart = email.substring(0, atIndex);
    final visibleCount = localPart.length < 3 ? localPart.length : 3;
    final maskedCount = (localPart.length - visibleCount).clamp(3, 32).toInt();
    return '${localPart.substring(0, visibleCount)}${List.filled(maskedCount, '*').join()}${email.substring(atIndex)}';
  }

  Future<void> _loginWithBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedToken = prefs.getString('saved_biometric_token');

    if (savedToken == null) {
      _clearBiometricPrefill();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Debes iniciar sesión con contraseña al menos una vez para usar huella.')),
      );
      return;
    }

    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!mounted) return;

      if (canCheckBiometrics || isDeviceSupported) {
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason:
              'Inicia sesión con tu huella para acceder a Salud Now',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (!mounted) return;

        if (didAuthenticate) {
          await prefs.setString('access_token', savedToken);
          final accountCheck = await ApiClient.get('/users/me');
          if (accountCheck.statusCode == 401 ||
              accountCheck.statusCode == 403 ||
              accountCheck.statusCode == 404) {
            await prefs.remove('access_token');
            await prefs.remove('saved_biometric_token');
            await prefs.remove('logged_username');
            _clearBiometricPrefill();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'La cuenta guardada ya no está disponible. Inicia sesión con otra cuenta.'),
              ));
            }
            return;
          }
          if (accountCheck.statusCode != 200) {
            await prefs.remove('access_token');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'No se pudo verificar la cuenta. Comprueba tu conexión e inténtalo de nuevo.'),
              ));
            }
            return;
          }
          ProfileImageHelper.updateCurrentUserAvatar(null);
          _navigateToHome();
        } else {
          _clearBiometricPrefill();
        }
      } else {
        _clearBiometricPrefill();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Tu dispositivo no soporta o no tiene configurada biometría.')),
        );
      }
    } catch (e) {
      _clearBiometricPrefill();
      debugPrint('Error de biometría: $e');
    }
  }

  void _clearBiometricPrefill() {
    if (!mounted) return;
    setState(() {
      _emailController.clear();
      _passwordController.clear();
      _emailShowsMask = false;
      _passwordShowsMask = false;
      _obscurePassword = true;
    });
  }

  Future<void> _login() async {
    if (!kIsWeb && (_emailShowsMask || _passwordShowsMask)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe tu correo y contraseña o inicia con huella.'),
        ),
      );
      return;
    }
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo y contraseña.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.postForm('/auth/login', {
        'username': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
      });
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        if (!kIsWeb) {
          await prefs.setString('saved_biometric_token', data['access_token']);
          await prefs.setString(
              'logged_username', _emailController.text.trim());
        } else {
          await prefs.remove('saved_biometric_token');
          await prefs.remove('logged_username');
        }
        ProfileImageHelper.updateCurrentUserAvatar(null);

        _navigateToHome();
      } else {
        var message = 'No se pudo iniciar sesión. Inténtalo de nuevo.';
        try {
          final responseData = jsonDecode(response.body);
          final detail = responseData is Map ? responseData['detail'] : null;
          if (response.statusCode == 401) {
            message = 'Correo o contraseña incorrectos.';
          } else if (detail is String && detail.isNotEmpty) {
            message = 'Error del servidor (${response.statusCode}): $detail';
          } else {
            message =
                'Error del servidor (${response.statusCode}). Inténtalo más tarde.';
          }
        } catch (_) {
          if (response.statusCode == 401) {
            message = 'Correo o contraseña incorrectos.';
          } else {
            message =
                'Error del servidor (${response.statusCode}). Inténtalo más tarde.';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToHome() async {
    // Check if the user is a doctor and needs a plan
    try {
      final userResponse = await ApiClient.get('/users/me');
      if (!mounted) return;
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);

        if (userData['role'] == 'doctor') {
          // It's a doctor, check if they have a profile/subscription
          final docResponse = await ApiClient.get('/doctors/me');
          if (!mounted) return;
          if (docResponse.statusCode == 200) {
            final docData = jsonDecode(docResponse.body);
            if (docData['clinic_join_status'] == 'pending') {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => const ClinicJoinPendingScreen()));
              return;
            }
            // Check their subscription status
            final subResp = await ApiClient.get('/subscriptions/me');
            if (!mounted) return;
            if (subResp.statusCode == 200) {
              final subData = jsonDecode(subResp.body);

              if (subData['is_clinic_member'] == true) {
                if (subData['clinic_access_blocked'] == true) {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => const ClinicAccessBlockedScreen()));
                  return;
                }
                if (subData['current'] != null) {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => const MainDoctorScreen()));
                  return;
                }
              }

              if (subData['current'] != null) {
                final graceEnd =
                    DateTime.parse(subData['current']['grace_end_date']);
                if (DateTime.now().isAfter(graceEnd)) {
                  // Grace period over!
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => SelectPlanScreen(
                          doctorData: docData, isRenewal: true)));
                  return;
                }
                // Active subscription (within grace period), proceed to home
              } else if (subData['pending'] != null) {
                // Pending subscription, go to waiting screen
                if (!mounted) return;
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => const PaymentPendingScreen()));
                return;
              } else {
                // No subscription at all
                if (!mounted) return;
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => SelectPlanScreen(
                        doctorData: docData, isRenewal: false)));
                return;
              }
            } else {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Error al cargar suscripción: ${subResp.statusCode}')));
              return; // Prevent bypass
            }
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Error al cargar perfil de doctor.')));
            return; // Prevent bypass
          }
        } else if (userData['role'] == 'clinic') {
          final subResp = await ApiClient.get('/subscriptions/me');
          if (!mounted) return;
          if (subResp.statusCode != 200) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('No se pudo verificar el plan de la clínica.')));
            return;
          }
          final subData = jsonDecode(subResp.body);
          final clinicData = <String, dynamic>{'role': 'clinic'};
          if (subData['current'] == null && subData['pending'] != null) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => const PaymentPendingScreen(isClinic: true)));
            return;
          }
          if (subData['current'] == null) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => SelectPlanScreen(doctorData: clinicData)));
            return;
          }
          final graceEnd = DateTime.tryParse(
              subData['current']['grace_end_date']?.toString() ?? '');
          if (graceEnd == null || DateTime.now().isAfter(graceEnd)) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) =>
                    SelectPlanScreen(doctorData: clinicData, isRenewal: true)));
            return;
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error al cargar datos del usuario.')));
        return; // Prevent bypass
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      return; // Prevent bypass
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
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
                if (kIsWeb) const WebHeader(),
                Expanded(
                  child: Container(
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
                        child: Padding(
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
                                  border: Border.all(
                                      color: const Color(0x80FFFFFF), width: 1),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Image.asset(
                                      'assets/logo.png',
                                      height: 100,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Icon(
                                            Icons.medical_services,
                                            size: 80,
                                            color: Color(0xFF0056B3));
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
                                      onTap: () {
                                        if (_emailShowsMask) {
                                          _emailController.clear();
                                          setState(
                                              () => _emailShowsMask = false);
                                        }
                                      },
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: 'Correo Electrónico',
                                        filled: true,
                                        fillColor: const Color(0x20FFFFFF),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0x60FFFFFF)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0x60FFFFFF)),
                                        ),
                                        prefixIcon: const Icon(Icons.email,
                                            color: Color(0xFF0B3C85)),
                                        labelStyle: const TextStyle(
                                            color: Color(0xFF0B2545)),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      style: const TextStyle(
                                          color: Color(0xFF0B2545)),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _passwordController,
                                      onTap: () {
                                        if (_passwordShowsMask) {
                                          _passwordController.clear();
                                          setState(() {
                                            _passwordShowsMask = false;
                                            _obscurePassword = true;
                                          });
                                        }
                                      },
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) =>
                                          _isLoading ? null : _login(),
                                      decoration: InputDecoration(
                                        labelText: 'Contraseña',
                                        filled: true,
                                        fillColor: const Color(0x20FFFFFF),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0x60FFFFFF)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0x60FFFFFF)),
                                        ),
                                        prefixIcon: const Icon(Icons.lock,
                                            color: Color(0xFF0B3C85)),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: const Color(0xFF0B3C85),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                        labelStyle: const TextStyle(
                                            color: Color(0xFF0B2545)),
                                      ),
                                      obscureText: _obscurePassword,
                                      style: const TextStyle(
                                          color: Color(0xFF0B2545)),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF0056B3),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2)),
                                                SizedBox(width: 12),
                                                Text('Ingresando...',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white)),
                                              ],
                                            )
                                          : const Text('Ingresar',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white)),
                                    ),
                                    if (kIsWeb) ...[
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: _openLatestRelease,
                                        icon:
                                            const Icon(Icons.android, size: 22),
                                        label: const Text('Descargar app'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF2E9D4D),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    if (!kIsWeb)
                                      IconButton(
                                        onPressed: _loginWithBiometrics,
                                        icon: const Icon(Icons.fingerprint,
                                            size: 50, color: Color(0xFF0056B3)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0x20FFFFFF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Wrap(
                                            alignment: WrapAlignment.center,
                                            children: [
                                              const Text(
                                                  '¿Aún no te has registrado? ',
                                                  style: TextStyle(
                                                      color: Color(0xFF475569),
                                                      fontSize: 12)),
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              RegisterScreen(
                                                                initialClinicInviteCode: kIsWeb
                                                                    ? Uri.base
                                                                            .queryParameters[
                                                                        'clinic_invite']
                                                                    : _clinicInviteCode,
                                                              )));
                                                },
                                                child: const Text(
                                                    'Crear cuenta',
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF0056B3),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            alignment: WrapAlignment.center,
                                            children: [
                                              const Text(
                                                  '¿Olvidaste tu contraseña? ',
                                                  style: TextStyle(
                                                      color: Color(0xFF475569),
                                                      fontSize: 12)),
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              const PasswordRecoveryScreen()));
                                                },
                                                child: const Text(
                                                    'Recupérala aquí',
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF0056B3),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold)),
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
                ),
                if (kIsWeb) const WebFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
