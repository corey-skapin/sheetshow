import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../services/auth_service.dart';

// T102: ForgotPasswordScreen

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _sent ? _buildSentState() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset your password',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Enter your email address and we\'ll send you a reset link.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendResetLink,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Reset Link'),
        ),
        TextButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text('Back to login'),
        ),
      ],
    );
  }

  Widget _buildSentState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.email_outlined, size: 64),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Check your inbox',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          "If that email is registered, you'll receive a reset link shortly.",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }

  Future<void> _sendResetLink() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authServiceProvider.notifier)
          .forgotPassword(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      // Always show "sent" to prevent user enumeration
      if (mounted) setState(() => _sent = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
