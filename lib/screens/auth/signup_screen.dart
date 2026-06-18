import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../services/auth_service.dart';
import '../../widgets/helpa_text_field.dart';

/// The Helpa signup screen.
///
/// Flow:
///   Step 1 — Role selection (Customer or Tasker)
///   Step 2 — Full signup form with validation
///
/// On success, Firebase Auth + Firestore documents are created and
/// [AuthGate] in main.dart automatically routes to the correct home screen.
class SignupScreen extends StatefulWidget {
  /// Called when the user taps "Already have an account? Sign in"
  final VoidCallback? onNavigateToLogin;

  const SignupScreen({super.key, this.onNavigateToLogin});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  int _step = 0; // 0 = role selection, 1 = form
  String _selectedRole = ''; // "customer" | "tasker"
  bool _isLoading = false;
  String? _errorMessage;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final AuthService _authService = AuthService();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step transitions
  // ---------------------------------------------------------------------------
  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
    });
    _animateToStep(1);
  }

  void _animateToStep(int step) async {
    await _fadeController.reverse();
    setState(() => _step = step);
    _slideController.reset();
    _fadeController.forward();
    _slideController.forward();
  }

  void _goBack() {
    if (_step == 0) return;
    _animateToStep(0);
    setState(() => _errorMessage = null);
  }

  // ---------------------------------------------------------------------------
  // Signup logic
  // ---------------------------------------------------------------------------
  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signUp(
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        role: _selectedRole,
      );
      // AuthGate in main.dart will automatically detect the new auth state
      // and route to the correct home screen. No manual navigation needed.
    } on Exception catch (e) {
      setState(() {
        _errorMessage = _friendlyError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Converts Firebase error codes into human-readable messages.
  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'An account with this email already exists. Try signing in.';
    } else if (raw.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    } else if (raw.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (raw.contains('network-request-failed')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _step == 0 ? _buildRoleStep() : _buildFormStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button (only on form step)
          if (_step == 1)
            GestureDetector(
              onTap: _goBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFF0057FF),
                ),
              ),
            ),
          if (_step == 1) const SizedBox(height: 20),

          // Logo + wordmark
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF0057FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'H',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'helpa',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0A0A0A),
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Step title
          Text(
            _step == 0 ? 'Create your account' : _roleHeadline(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A0A0A),
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _step == 0
                ? 'First, tell us how you\'ll use Helpa'
                : 'Fill in your details to get started',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w400,
            ),
          ),

          // Step indicator
          const SizedBox(height: 20),
          Row(
            children: [
              _stepDot(active: true),
              const SizedBox(width: 6),
              _stepDot(active: _step == 1),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _roleHeadline() {
    return _selectedRole == 'customer'
        ? 'Join as a Customer'
        : 'Join as a Tasker';
  }

  Widget _stepDot({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0057FF) : const Color(0xFFD0DEFF),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Role Selection
  // ---------------------------------------------------------------------------
  Widget _buildRoleStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _RoleCard(
            icon: Icons.person_outline_rounded,
            title: 'I need help',
            subtitle:
                'Book trusted taskers for home services, errands, and deliveries.',
            accentColor: const Color(0xFF0057FF),
            isSelected: _selectedRole == 'customer',
            onTap: () => _selectRole('customer'),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            icon: Icons.handyman_outlined,
            title: 'I want to work',
            subtitle:
                'Offer your skills and earn money by completing jobs near you.',
            accentColor: const Color(0xFF00B274),
            isSelected: _selectedRole == 'tasker',
            onTap: () => _selectRole('tasker'),
          ),
          const Spacer(),
          _buildLoginLink(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Signup Form
  // ---------------------------------------------------------------------------
  Widget _buildFormStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role badge
            _RoleBadge(role: _selectedRole),
            const SizedBox(height: 24),

            // Full name
            HelpaTextField(
              label: 'Full name',
              hint: 'e.g. Kwame Mensah',
              controller: _fullNameController,
              prefixIcon: Icons.person_outline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your full name';
                }
                if (v.trim().split(' ').length < 2) {
                  return 'Enter your first and last name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            HelpaTextField(
              label: 'Email address',
              hint: 'you@example.com',
              controller: _emailController,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
                if (!emailRegex.hasMatch(v.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone
            HelpaTextField(
              label: 'Phone number',
              hint: '024 000 0000',
              controller: _phoneController,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your phone number';
                }
                final digits = v.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 9) {
                  return 'Enter a valid Ghanaian phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            HelpaTextField(
              label: 'Password',
              hint: 'At least 6 characters',
              controller: _passwordController,
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Create a password';
                if (v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm password
            HelpaTextField(
              label: 'Confirm password',
              hint: 'Re-enter your password',
              controller: _confirmPasswordController,
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSignup(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirm your password';
                if (v != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            // Tasker notice
            if (_selectedRole == 'tasker') ...[
              const SizedBox(height: 16),
              _TaskerNotice(),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: _errorMessage!),
            ],

            const SizedBox(height: 28),

            // Submit button
            _HelpaButton(
              label: 'Create Account',
              isLoading: _isLoading,
              onTap: _handleSignup,
              color: _selectedRole == 'tasker'
                  ? const Color(0xFF00B274)
                  : const Color(0xFF0057FF),
            ),

            const SizedBox(height: 20),
            _buildLoginLink(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared: Login link
  // ---------------------------------------------------------------------------
  Widget _buildLoginLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          text: 'Already have an account? ',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: 'Sign in',
              style: const TextStyle(
                color: Color(0xFF0057FF),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = widget.onNavigateToLogin,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

/// Card used in the role selection step.
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              isSelected ? accentColor.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFE5E9F0),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accentColor : const Color(0xFF0A0A0A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : const Color(0xFFCDD5E0),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill badge showing selected role on the form step.
class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isTasker = role == 'tasker';
    final color = isTasker ? const Color(0xFF00B274) : const Color(0xFF0057FF);
    final label = isTasker ? 'Joining as Tasker' : 'Joining as Customer';
    final icon =
        isTasker ? Icons.handyman_outlined : Icons.person_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Info box shown to taskers about the approval process.
class _TaskerNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'After signing up, you\'ll need to upload a valid ID. '
              'Our team will verify and approve your profile before you start receiving jobs.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.brown.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Red error banner shown when signup fails.
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFFF3B30)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFB71C1C),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary CTA button with loading state.
class _HelpaButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  final Color color;

  const _HelpaButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isLoading ? color.withValues(alpha: 0.7) : color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
