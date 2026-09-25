import 'package:flutter/material.dart';
import 'home_tab.dart';

class MainDoctorScreen extends StatefulWidget {
  const MainDoctorScreen({super.key});

  @override
  State<MainDoctorScreen> createState() => _MainDoctorScreenState();
}

class _MainDoctorScreenState extends State<MainDoctorScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const Center(child: Text('Agendar')),
    const SizedBox.shrink(), // Placeholder para el botón central
    const Center(child: Text('Mi disponibilidad')),
    const Center(child: Text('Perfil')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Importante para que el body vaya por debajo del BottomAppBar transparente
      body: Stack(
        children: [
          _tabs[_currentIndex],
          // Botón flotante de chat (estilo Flet)
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'chatFAB',
              backgroundColor: const Color(0xFF0056B3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onPressed: () {},
              child: const Icon(Icons.chat, color: Colors.white),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'searchFAB',
        backgroundColor: const Color(0xFF0056B3),
        shape: const CircleBorder(),
        onPressed: () {},
        child: const Icon(Icons.search, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.calendar_today, 'Agendar', 1),
              const SizedBox(width: 48), // Espacio para la muesca central
              _buildNavItem(Icons.schedule, 'Mi disponibilidad', 3),
              _buildNavItem(Icons.person_outline, 'Perfil', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF0056B3) : const Color(0xFF475569);
    
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
