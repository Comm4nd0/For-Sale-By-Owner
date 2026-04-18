import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/branded_app_bar.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool embedded;
  const LoginScreen({super.key, this.embedded = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  String? _error;

  // When non-null, the server has accepted email+password and is waiting
  // for a TOTP code against this challenge_id before issuing a token.
  String? _challengeId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _error = null);

    final authService = context.read<AuthService>();
    final result = await authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    switch (result.status) {
      case LoginStatus.success:
        if (!widget.embedded) Navigator.pop(context);
        // Embedded: MainShell rebuilds on auth change.
        break;
      case LoginStatus.requires2FA:
        setState(() {
          _challengeId = result.challengeId;
          _error = null;
        });
        break;
      case LoginStatus.invalidCredentials:
        setState(() => _error = 'Invalid email or password');
        break;
      case LoginStatus.failure:
        setState(() => _error = result.error ?? 'Login failed');
        break;
    }
  }

  Future<void> _verify2FA() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator.');
      return;
    }

    setState(() => _error = null);

    final authService = context.read<AuthService>();
    final result = await authService.completeTwoFactorLogin(
      challengeId: _challengeId!,
      code: code,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      if (!widget.embedded) Navigator.pop(context);
    } else if (result.status == LoginStatus.failure &&
        (result.error ?? '').contains('again')) {
      // Attempts exhausted or challenge gone — fall back to the
      // password form.
      setState(() {
        _challengeId = null;
        _codeController.clear();
        _error = result.error;
      });
    } else {
      setState(() => _error = result.error ?? 'Invalid code');
    }
  }

  void _cancelTwoFactor() {
    setState(() {
      _challengeId = null;
      _codeController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final showTwoFactor = _challengeId != null;

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: showTwoFactor
          ? _buildTwoFactorForm(authService)
          : _buildLoginForm(authService),
    );

    if (widget.embedded) {
      return Scaffold(
        appBar: BrandedAppBar.build(context: context),
        body: body,
      );
    }

    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      body: body,
    );
  }

  Widget _buildLoginForm(AuthService authService) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) _buildErrorBanner(_error!),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: authService.isLoading ? null : _login,
            child: authService.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Login'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              if (widget.embedded) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              }
            },
            child: const Text("Don't have an account? Register"),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoFactorForm(AuthService authService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Two-factor authentication',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the 6-digit code from your authenticator app to finish '
          'signing in.',
          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_error != null) _buildErrorBanner(_error!),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
            fontFamily: 'monospace',
          ),
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _verify2FA(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: authService.isLoading ? null : _verify2FA,
          child: authService.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify and sign in'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: authService.isLoading ? null : _cancelTwoFactor,
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: Colors.red[700])),
    );
  }
}
