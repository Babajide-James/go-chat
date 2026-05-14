import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../core/theme/app_theme.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    final nav = Navigator.of(context);
    bool success;
    if (_isSignUp) {
      success = await vm.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _displayNameController.text.trim(),
      );
    } else {
      success = await vm.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
    if (success && mounted) nav.pushReplacementNamed('/chats');
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppTheme.softWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),

                    // ── Logo ──────────────────────────────────────────────
                    Image.asset(
                      'assets/images/go_blogo.png',
                      height: 130,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),

                    // ── Title ─────────────────────────────────────────────
                    Text(
                      _isSignUp ? 'Create Account' : 'Welcome Back',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSignUp
                          ? 'Join Go Chat and start messaging'
                          : 'Sign in to continue to Go Chat',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Error Banner ──────────────────────────────────────
                    if (authViewModel.errorMessage != null)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade600, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authViewModel.errorMessage!,
                                style: TextStyle(
                                    color: Colors.red.shade700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Display Name (sign-up only) ────────────────────────
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _displayNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          prefixIcon: Icon(Icons.person_outline,
                              color: AppTheme.textLight),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a display name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Email ─────────────────────────────────────────────
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined,
                            color: AppTheme.textLight),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Password ──────────────────────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: AppTheme.textLight),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppTheme.textLight,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Password must be at least 6 characters'
                          : null,
                    ),

                    const SizedBox(height: 32),

                    // ── Submit Button ─────────────────────────────────────
                    authViewModel.isLoading
                        ? const SizedBox(
                            height: 52,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () => _submit(authViewModel),
                            child: Text(_isSignUp ? 'Create Account' : 'Sign In'),
                          ),

                    // ── Spacer pushes toggle to bottom ─────────────────────
                    const Spacer(),

                    // ── Toggle Sign In / Sign Up ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignUp
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                            style: const TextStyle(
                              color: AppTheme.textLight,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              setState(() => _isSignUp = !_isSignUp);
                              authViewModel.clearError();
                            },
                            child: Text(
                              _isSignUp ? 'Sign In' : 'Sign Up',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
