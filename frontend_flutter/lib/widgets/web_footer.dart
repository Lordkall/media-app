import 'package:flutter/material.dart';
import '../screens/legal_screens.dart';

class WebFooter extends StatelessWidget {
  const WebFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0056B3),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        children: [
          const Text(
            'Copyright © 2026 Salud Now. RIF J-501934070, Salud Now C.A.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen())),
                child: const Text('Términos y Condiciones', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CookiesPolicyScreen())),
                child: const Text('Cookies', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                child: const Text('Privacidad', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
