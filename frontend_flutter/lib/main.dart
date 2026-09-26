import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const SaludNowApp());
}

class SaludNowApp extends StatelessWidget {
  const SaludNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salud Now',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F4C81)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFE2F1F8), // Light blue background matching the image
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.green,
          contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const LoginScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const Center(child: Text("Agendar")),
    const Center(child: Text("Buscar")),
    const Center(child: Text("Mi disponibilidad")),
    const Center(child: Text("Perfil")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0F4C81),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Agendar'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Mi disponibilidad'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF0F4C81),
        child: const Icon(Icons.search, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage('https://cdn-icons-png.flaticon.com/512/3069/3069172.png'), // Placeholder cat doctor
                  backgroundColor: Colors.white,
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola, Doctor!',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81)),
                      ),
                      Row(
                        children: [
                          Chip(
                            label: Text('Doctor', style: TextStyle(color: Colors.white, fontSize: 10)),
                            backgroundColor: Colors.blueGrey,
                            padding: EdgeInsets.zero,
                          ),
                          SizedBox(width: 8),
                          Text('prueba@gmail.com', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, color: Color(0xFF0F4C81)),
                  onPressed: () {},
                )
              ],
            ),
          ),
          
          const Divider(),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Menú Principal',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fecha:', style: TextStyle(fontSize: 16)),
                Row(
                  children: const [
                    Icon(Icons.calendar_today, color: Color(0xFF0F4C81), size: 18),
                    SizedBox(width: 8),
                    Text('24/09/2026', style: TextStyle(fontSize: 16, color: Color(0xFF0F4C81))),
                  ],
                ),
              ],
            ),
          ),
          
          // Appointments List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAppointmentCard('Juan Pérez', 'Clínica Central - Consultorio 4', 'Razona la visita trencala', '03:00 PM', '#1'),
                const SizedBox(height: 16),
                _buildAppointmentCard('María Gómez', 'Clínica Central - Consultorio 4', 'Razon de la visita', '03:30 PM', '#2'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(String name, String clinic, String reason, String time, String turn) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F4C81),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Paciente: $name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Confirmada', style: TextStyle(color: Colors.white, fontSize: 10)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(clinic, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('24/09/2026 - $time', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('Turno $turn', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
