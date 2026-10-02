import 'package:flutter/material.dart';
import '../screens/landing_screens.dart';
import '../screens/login_screen.dart';

class WebHeader extends StatelessWidget {
  const WebHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0056B3),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          InkWell(
            onTap: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: Container(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/logo_transparent.png',
                  height: 50,
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.health_and_safety, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),
          // Navigation Links
          Wrap(
            spacing: 24,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ForUsersScreen()));
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Para Usuarios', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AlliedDoctorsScreen()));
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Doctores Aliados', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AlliedClinicsScreen()));
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Clínicas Aliadas', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqScreen()));
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Preguntas Frecuentes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
