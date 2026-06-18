import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/helpa_text_field.dart';

/// The Helpa login screen.
///
/// Flow:
///   - Email + password login
///   - Forgot password (inline modal sheet)
///   - Link to signup screen
///
/// On success, [AuthGate] in main.dart automatically routes
/// the user to the correct home screen based on their role.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSignup;

  const LoginScreen({super.key, this.onNavigateToSignup});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  bool _isLoading = false;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Login logic
  // ---------------------------------------------------------------------------
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // AuthGate handles routing automatically on auth state change
    } on Exception catch (e) {
      setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Incorrect email or password. Please try again.';
    } else if (raw.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    } else if (raw.contains('network-request-failed')) {
      return 'No internet connection. Please check your network.';
    } else if (raw.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ---------------------------------------------------------------------------
  // Forgot password sheet
  // ---------------------------------------------------------------------------
  void _showForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(authService: _authService),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  _buildTopSection(),
                  const SizedBox(height: 40),
                  _buildForm(),
                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 28),
                  _buildSignupLink(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top section — logo, headline, subtext
  // ---------------------------------------------------------------------------
  Widget _buildTopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0057FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Center(
                child: Text(
                  'H',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
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

        const SizedBox(height: 36),

        // Headline
        const Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A0A0A),
            letterSpacing: -1,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue to your account',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Form
  // ---------------------------------------------------------------------------
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Email
          HelpaTextField(
            label: 'Email address',
            hint: 'you@example.com',
            controller: _emailController,
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
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

          // Password
          HelpaTextField(
            label: 'Password',
            controller: _passwordController,
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _handleLogin(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your password';
              return null;
            },
          ),

          // Forgot password link — right-aligned under password field
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showForgotPassword,
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF0057FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Error banner
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _errorMessage!),
          ],

          const SizedBox(height: 28),

          // Sign in button
          _HelpaButton(
            label: 'Sign In',
            isLoading: _isLoading,
            onTap: _handleLogin,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Divider
  // ---------------------------------------------------------------------------
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'New to Helpa?',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.5)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Signup link
  // ---------------------------------------------------------------------------
  Widget _buildSignupLink() {
    return Center(
      child: GestureDetector(
        onTap: widget.onNavigateToSignup,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF0057FF).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: RichText(
              text: const TextSpan(
                text: 'Create an account  ',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF0057FF),
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: '→',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Forgot Password Bottom Sheet
// =============================================================================

class _ForgotPasswordSheet extends StatefulWidget {
  final AuthService authService;

  const _ForgotPasswordSheet({required this.authService});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.authService.sendPasswordReset(_emailController.text);
      setState(() => _emailSent = true);
    } on Exception catch (e) {
      setState(() {
        _error = e.toString().contains('user-not-found')
            ? 'No account found with this email.'
            : 'Could not send reset email. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 32 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (!_emailSent) ...[
            // Header
            const Text(
              'Reset your password',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A0A0A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the email address linked to your account and we\'ll send you a reset link.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Email field
            Form(
              key: _formKey,
              child: HelpaTextField(
                label: 'Email address',
                hint: 'you@example.com',
                controller: _emailController,
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _sendReset(),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter your email address';
                  }
                  final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _error!),
            ],

            const SizedBox(height: 24),

            // Send button
            _HelpaButton(
              label: 'Send Reset Link',
              isLoading: _isLoading,
              onTap: _sendReset,
            ),
          ] else ...[
            // Success state
            _EmailSentConfirmation(
              email: _emailController.text.trim(),
              onClose: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Email Sent Confirmation (inside forgot password sheet)
// =============================================================================

class _EmailSentConfirmation extends StatelessWidget {
  final String email;
  final VoidCallback onClose;

  const _EmailSentConfirmation({
    required this.email,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: Color(0xFF00B274),
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Check your inbox',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A0A0A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'We\'ve sent a password reset link to\n$email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Check your spam folder if you don\'t see it.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 28),
        _HelpaButton(
          label: 'Back to Sign In',
          isLoading: false,
          onTap: onClose,
        ),
      ],
    );
  }
}

// =============================================================================
// Shared sub-widgets (scoped to this file)
// =============================================================================

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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

class _HelpaButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  final Color color;

  const _HelpaButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  }) : color = const Color(0xFF0057FF);

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
              color: color.withValues(alpha: 0.28),
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
