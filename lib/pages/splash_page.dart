import 'package:flutter/material.dart';
import 'home_page.dart';

/// Compatibility entry: no artificial timer or advertisement-style skip gate.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) => const HomePage();
}
