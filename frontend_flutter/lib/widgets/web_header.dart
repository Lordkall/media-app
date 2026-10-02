import 'package:flutter/material.dart';
import '../screens/landing_screens.dart';
import '../screens/login_screen.dart';

class WebHeader extends StatelessWidget {
  const WebHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      width: double.infinity,
      color: const Color(0xFF0056B3),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          InkWell(
            onTap: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Image.asset(
                'assets/logo_white.png',
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.health_and_safety, color: Colors.white, size: 36),
              ),
            ),
          ),
          // Navigation Links
          if (isDesktop)
            Wrap(
              spacing: 24,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _buildMenuItems(context, isDesktop: true),
            )
          else
            PopupMenuButton<String>(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Menú', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Icon(Icons.keyboard_arrow_down, color: Colors.white),
                ],
              ),
              color: Colors.white,
              onSelected: (value) {
                _navigateTo(context, value);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'usuarios',
                  child: Text('Para Usuarios', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                const PopupMenuItem<String>(
                  value: 'doctores',
                  child: Text('Doctores Aliados', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                const PopupMenuItem<String>(
                  value: 'clinicas',
                  child: Text('Clínicas Aliadas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                const PopupMenuItem<String>(
                  value: 'faq',
                  child: Text('Preguntas Frecuentes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context, {required bool isDesktop}) {
    final color = isDesktop ? Colors.white : Colors.black;
    return [
      TextButton(
        onPressed: () => _navigateTo(context, 'usuarios'),
        style: TextButton.styleFrom(foregroundColor: color),
        child: const Text('Para Usuarios', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      TextButton(
        onPressed: () => _navigateTo(context, 'doctores'),
        style: TextButton.styleFrom(foregroundColor: color),
        child: const Text('Doctores Aliados', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      TextButton(
        onPressed: () => _navigateTo(context, 'clinicas'),
        style: TextButton.styleFrom(foregroundColor: color),
        child: const Text('Clínicas Aliadas', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      TextButton(
        onPressed: () => _navigateTo(context, 'faq'),
        style: TextButton.styleFrom(foregroundColor: color),
        child: const Text('Preguntas Frecuentes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
  }

  void _navigateTo(BuildContext context, String route) {
    switch (route) {
      case 'usuarios':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ForUsersScreen()));
        break;
      case 'doctores':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AlliedDoctorsScreen()));
        break;
      case 'clinicas':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AlliedClinicsScreen()));
        break;
      case 'faq':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqScreen()));
        break;
    }
  }
}
