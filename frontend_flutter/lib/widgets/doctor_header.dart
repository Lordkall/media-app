import 'package:flutter/material.dart';

class DoctorHeader extends StatelessWidget {
  final String name;
  final String email;

  const DoctorHeader({super.key, required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 35,
          backgroundColor: Colors.white,
          backgroundImage: AssetImage('assets/logo.png'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¡Hola, $name!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0B2545))),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF29B6F6), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Doctor', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications, color: Color(0xFF0056B3), size: 28),
          onPressed: () {},
        ),
      ],
    );
  }
}
