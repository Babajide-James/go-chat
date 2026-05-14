import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/error_display.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Sign up' : 'Login')),
      body: authViewModel.isLoading
          ? const LoadingIndicator()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (authViewModel.errorMessage != null)
                    ErrorDisplay(message: authViewModel.errorMessage!),
                  if (authViewModel.errorMessage != null)
                    const SizedBox(height: 16),
                  if (_isSignUp)
                    TextField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(labelText: 'Display Name'),
                    ),
                  if (_isSignUp)
                    const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  if (!_isSignUp)
                    ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final success = await authViewModel.signIn(
                          _emailController.text,
                          _passwordController.text,
                        );
                        if (success && mounted) {
                          navigator.pushReplacementNamed('/chats');
                        }
                      },
                      child: const Text('Sign in'),
                    ),
                  if (_isSignUp)
                    ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final success = await authViewModel.signUp(
                          _emailController.text,
                          _passwordController.text,
                          _displayNameController.text,
                        );
                        if (success && mounted) {
                          navigator.pushReplacementNamed('/chats');
                        }
                      },
                      child: const Text('Create Account'),
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                      authViewModel.clearError();
                    },
                    child: Text(_isSignUp
                        ? 'Already have an account? Sign in'
                        : 'Need an account? Sign up'),
                  ),
                ],
              ),
            ),
    );
  }
}
