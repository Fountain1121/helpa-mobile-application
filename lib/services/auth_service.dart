import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/tasker_model.dart';

/// Handles all Firebase Authentication and user document creation.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Sign Up
  // ---------------------------------------------------------------------------

  /// Creates a Firebase Auth account, then writes the user document to
  /// Firestore. If the role is "tasker", also creates a tasker profile doc.
  Future<UserModel> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role, // "customer" | "tasker"
    String? location,
  }) async {
    // 1. Create the Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final now = DateTime.now();

    // 2. Build the user model
    final user = UserModel(
      uid: uid,
      fullName: fullName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: role,
      location: location?.trim(),
      createdAt: now,
      isActive: true,
    );

    // 3. Write to Firestore `users` collection
    await _db.collection('users').doc(uid).set(user.toMap());

    // 4. If tasker, also create the tasker profile doc
    if (role == 'tasker') {
      final tasker = TaskerModel(
        uid: uid,
        skills: [],
        idVerified: false,
        isApproved: false,
        rating: 0.0,
        totalJobsCompleted: 0,
        earnings: 0.0,
        availability: true,
      );
      await _db.collection('taskers').doc(uid).set(tasker.toMap());
    }

    // 5. Update the Firebase Auth display name
    await credential.user!.updateDisplayName(fullName.trim());

    return user;
  }

  // ---------------------------------------------------------------------------
  // Sign In
  // ---------------------------------------------------------------------------

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final doc = await _db.collection('users').doc(uid).get();

    if (!doc.exists) {
      throw Exception('User profile not found. Please contact support.');
    }

    return UserModel.fromDoc(doc);
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Password Reset
  // ---------------------------------------------------------------------------

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ---------------------------------------------------------------------------
  // Current User
  // ---------------------------------------------------------------------------

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
