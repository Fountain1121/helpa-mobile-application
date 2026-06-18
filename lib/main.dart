import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_wrapper.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/tasker/tasker_home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HelpaApp());
}

class HelpaApp extends StatelessWidget {
  const HelpaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0057FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const AuthGate(),
    );
  }
}

/// AuthGate listens to Firebase auth state and routes the user
/// to the correct experience based on their role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While Firebase is resolving auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // No user logged in — show login/signup
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginPlaceholder();
        }

        // User is logged in — resolve their role from Firestore
        return RoleRouter(uid: snapshot.data!.uid);
      },
    );
  }
}

/// Fetches the user's role from Firestore and routes accordingly.
class RoleRouter extends StatelessWidget {
  final String uid;
  const RoleRouter({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // User document not found — log them out and show login
          FirebaseAuth.instance.signOut();
          return const LoginPlaceholder();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final role = data['role'] as String? ?? 'customer';

        switch (role) {
          case 'tasker':
            return const TaskerHomePlaceholder();
          case 'admin':
            return const AdminHomePlaceholder();
          case 'customer':
          default:
            return const CustomerHomePlaceholder();
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder screens — replace these with your real screens as you build them
// ---------------------------------------------------------------------------

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0057FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'helpa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class LoginPlaceholder extends StatelessWidget {
  const LoginPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}

class CustomerHomePlaceholder extends StatelessWidget {
  const CustomerHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomerHomeScreen();
  }
}

class TaskerHomePlaceholder extends StatelessWidget {
  const TaskerHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const TaskerHomeScreen();
  }
}

class AdminHomePlaceholder extends StatelessWidget {
  const AdminHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardScreen();
  }
}
