import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

/// Manages navigation between Login and Signup within the unauthenticated flow.
/// Passed to main.dart's LoginPlaceholder as the unauthenticated entry point.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with SingleTickerProviderStateMixin {
  bool _showLogin = false;

  late AnimationController _switchController;
  late Animation<double> _switchAnimation;

  @override
  void initState() {
    super.initState();
    _switchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _switchAnimation = CurvedAnimation(
      parent: _switchController,
      curve: Curves.easeInOut,
    );
    _switchController.forward();
  }

  @override
  void dispose() {
    _switchController.dispose();
    super.dispose();
  }

  Future<void> _switchTo(bool login) async {
    await _switchController.reverse();
    setState(() => _showLogin = login);
    _switchController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _switchAnimation,
      child: _showLogin
          ? LoginScreen(
              onNavigateToSignup: () => _switchTo(false),
            )
          : SignupScreen(
              onNavigateToLogin: () => _switchTo(true),
            ),
    );
  }
}
