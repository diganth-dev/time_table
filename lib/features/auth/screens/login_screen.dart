import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _collegeNameController = TextEditingController();

  // State
  bool _isSignUp = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Animation controller for page entrance
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _collegeNameController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  // Email format validator supporting standard Firebase email formats
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your college email';
    }
    final email = value.trim();
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address (e.g. name@college.edu or name@gmail.com)';
    }
    return null;
  }

  // Password validator
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (_isSignUp && value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Convert Firebase error codes into clear, professional messages
  String _mapFirebaseError(dynamic error) {
    if (error is fb_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'The college email address is formatted incorrectly.';
        case 'user-not-found':
          return 'No TimePilot account found for this email. Please register or verify the address.';
        case 'wrong-password':
          return 'Incorrect password. Please verify and try again, or use "Forgot Password?".';
        case 'invalid-credential':
          return 'Invalid credentials. Please verify your email and password.';
        case 'email-already-in-use':
          return 'An account already exists with this college email. Please sign in instead.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 6 characters with a combination of letters and numbers.';
        case 'user-disabled':
          return 'This user account has been disabled. Please contact your college administrator.';
        case 'too-many-requests':
          return 'Too many unsuccessful attempts. Access has been temporarily restricted for security. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled in Firebase Console.';
        default:
          return error.message ?? 'An unexpected authentication error occurred.';
      }
    }
    final raw = error.toString();
    if (raw.contains('No pending staff invitation')) {
      return 'No pending staff invitation found for this email. Contact your college admin.';
    }
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return 'Authentication failed. Please verify your credentials and try again.';
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return; // Prevent multiple clicks while loading

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSignUp &&
        _passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match. Please re-enter your password.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authController = ref.read(authControllerProvider.notifier);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        final name = _nameController.text.trim();
        final collegeName = _collegeNameController.text.trim();

        await authController.register(
          email: email,
          password: password,
          name: name.isNotEmpty ? name : 'College Administrator',
          role: UserRole.collegeAdmin,
          collegeName: collegeName.isNotEmpty ? collegeName : null,
        );
      } else {
        await authController.signIn(
          email: email,
          password: password,
        );
      }

      if (mounted) {
        // Navigation after login/registration
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _mapFirebaseError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailController.text.trim());
    final resetFormKey = GlobalKey<FormState>();
    bool isResetting = false;
    String? resetError;

    showDialog(
      context: context,
      barrierDismissible: !isResetting,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: Color(0xFF0051D5), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'TimePilot Account Recovery',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Form(
              key: resetFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your registered college email and we\'ll send you a secure link to reset your password.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (resetError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              resetError!,
                              style: const TextStyle(
                                  color: Color(0xFFB91C1C), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: resetEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    enabled: !isResetting,
                    decoration: InputDecoration(
                      labelText: 'College Email',
                      hintText: 'e.g. name@college.edu',
                      prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isResetting
                            ? null
                            : () => Navigator.of(dialogCtx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0051D5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                        onPressed: isResetting
                            ? null
                            : () async {
                                if (!resetFormKey.currentState!.validate()) {
                                  return;
                                }
                                setDialogState(() {
                                  isResetting = true;
                                  resetError = null;
                                });

                                try {
                                  final authController =
                                      ref.read(authControllerProvider.notifier);
                                  await authController.sendPasswordResetEmail(
                                      resetEmailCtrl.text.trim());

                                  if (context.mounted) {
                                    Navigator.of(dialogCtx).pop();
                                    setState(() {
                                      _successMessage =
                                          'Password reset link dispatched to ${resetEmailCtrl.text.trim()}. Please check your inbox.';
                                      _errorMessage = null;
                                    });
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    resetError = _mapFirebaseError(e);
                                    isResetting = false;
                                  });
                                }
                              },
                        icon: isResetting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: Text(isResetting ? 'Sending...' : 'Send Reset Link'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWideDesktop = size.width >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: isWideDesktop
                ? Row(
                    children: [
                      // Left Hero / Branding Panel (Desktop)
                      Expanded(
                        flex: 5,
                        child: _buildDesktopHero(context),
                      ),
                      // Right Auth Form Container
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 48, vertical: 32),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: _buildAuthCard(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _buildAuthCard(context),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // Left Hero Side Panel for Desktop
  Widget _buildDesktopHero(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1C30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1C30),
            Color(0xFF132A46),
            Color(0xFF0F172A),
          ],
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0051D5),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0051D5).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child:
                    const Icon(Icons.table_chart, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TimePilot',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Automated College Timetable Generator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Core Value Propositions
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        color: Color(0xFF60A5FA), size: 14),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Academic Timetable Engine',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF93C5FD),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Next-Generation\nInstitutional Scheduling.',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Constraint-driven timetable generation, conflict detection, professor workload limits, and multi-batch laboratory scheduling built for higher education.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFCBD5E1),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),
              _buildFeatureCheck('Conflict-free professor, room & section matrix'),
              const SizedBox(height: 12),
              _buildFeatureCheck('Separated B1/B2 batch laboratory allocation'),
              const SizedBox(height: 12),
              _buildFeatureCheck('Secure multi-college data isolation via Firebase Auth'),
              const SizedBox(height: 12),
              _buildFeatureCheck('Print, PDF, CSV, and matrix timetable exports'),
            ],
          ),

          // Footer
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Academic Core v2.4 • Production Ready',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCheck(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0051D5).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Color(0xFF60A5FA), size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Central Authentication Card
  Widget _buildAuthCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 960;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mobile / Tablet Header Branding
            if (isMobile) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0051D5),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0051D5).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.table_chart,
                      color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'TimePilot',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Automated College Timetable Generator',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Card Title & Subtitle
            Text(
              _isSignUp ? 'Create College Account' : 'Sign In',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp
                  ? 'Set up your institution credentials to begin automated scheduling'
                  : 'Enter your credentials to access your college timetable portal',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),

            // Mode Toggle (Sign In / Register)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleTab(
                      title: 'Sign In',
                      isActive: !_isSignUp,
                      onTap: () {
                        if (_isSignUp) {
                          setState(() {
                            _isSignUp = false;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildToggleTab(
                      title: 'Create Account',
                      isActive: _isSignUp,
                      onTap: () {
                        if (!_isSignUp) {
                          setState(() {
                            _isSignUp = true;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Feedback Message Banner
            if (_errorMessage != null) ...[
              _buildFeedbackBanner(
                message: _errorMessage!,
                isError: true,
                onDismiss: () => setState(() => _errorMessage = null),
              ),
              const SizedBox(height: 16),
            ],
            if (_successMessage != null) ...[
              _buildFeedbackBanner(
                message: _successMessage!,
                isError: false,
                onDismiss: () => setState(() => _successMessage = null),
              ),
              const SizedBox(height: 16),
            ],

            // Registration specific fields
            if (_isSignUp) ...[
              // Full Name
              _buildInputField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'e.g. Dr. Alan Turing',
                icon: Icons.person_outline_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Institution Name
              _buildInputField(
                controller: _collegeNameController,
                label: 'College / Institution Name',
                hint: 'e.g. Apex Institute of Engineering',
                icon: Icons.apartment_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your institution name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // College Email Field
            _buildInputField(
              controller: _emailController,
              label: 'College Email',
              hint: 'e.g. professor@college.edu or name@gmail.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),

            // Password Field with Smooth Animated Eye Icon
            _buildPasswordField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              isVisible: _isPasswordVisible,
              onToggleVisibility: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
              validator: _validatePassword,
            ),

            // Confirm Password Field for Sign Up
            if (_isSignUp) ...[
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                hint: 'Re-enter your password',
                isVisible: _isConfirmPasswordVisible,
                onToggleVisibility: () {
                  setState(() =>
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                },
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (val != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],

            // Forgot Password Link (Sign In mode)
            if (!_isSignUp) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0051D5),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Animated Submit Button with Loading State
            _buildAnimatedSubmitButton(),

            const SizedBox(height: 20),

            // Bottom Switcher
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? 'Already have a college account?'
                        : 'Don\'t have an account?',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                    child: Text(
                      _isSignUp ? 'Sign In' : 'Create Account',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0051D5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Toggle Tab between Sign In and Create Account
  Widget _buildToggleTab({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  // General Text Input Field with Label
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: Icon(icon, size: 19, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF8F9FF),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF0051D5), width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.8),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // Password Input Field with Smooth Animated Eye Icon
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 19, color: Color(0xFF64748B)),
            suffixIcon: _buildSmoothAnimatedEye(
              isVisible: isVisible,
              onToggle: onToggleVisibility,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FF),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF0051D5), width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.8),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // Smooth Animated Eye Toggle Icon
  Widget _buildSmoothAnimatedEye({
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return IconButton(
      onPressed: _isLoading ? null : onToggle,
      tooltip: isVisible ? 'Hide password' : 'Show password',
      splashRadius: 20,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInBack,
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: Tween<double>(begin: 0.15, end: 0.0).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.75, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
          );
        },
        child: Icon(
          isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          key: ValueKey<bool>(isVisible),
          color: isVisible ? const Color(0xFF0051D5) : const Color(0xFF64748B),
          size: 20,
        ),
      ),
    );
  }

  // Modern Animated Submit Button with Loading State
  Widget _buildAnimatedSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0051D5),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              const Color(0xFF0051D5).withValues(alpha: 0.65),
          elevation: _isLoading ? 0 : 2,
          shadowColor: const Color(0xFF0051D5).withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _isLoading ? null : _handleSubmit,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? Row(
                  key: const ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _isSignUp ? 'Creating Account...' : 'Signing in...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  key: ValueKey(_isSignUp ? 'signup' : 'signin'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSignUp
                          ? Icons.person_add_rounded
                          : Icons.login_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isSignUp
                            ? 'Create TimePilot Account'
                            : 'Sign In to TimePilot',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // Feedback Banner for Errors or Success
  Widget _buildFeedbackBanner({
    required String message,
    required bool isError,
    required VoidCallback onDismiss,
  }) {
    final bgColor = isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final borderColor =
        isError ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC);
    final textColor =
        isError ? const Color(0xFF991B1B) : const Color(0xFF166534);
    final iconColor =
        isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDismiss,
            child: Icon(Icons.close, color: textColor.withValues(alpha: 0.6), size: 16),
          ),
        ],
      ),
    );
  }
}
