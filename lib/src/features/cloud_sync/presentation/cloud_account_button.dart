import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/secure_sign_out_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CloudAccountButton extends ConsumerWidget {
  const CloudAccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cloudConfigProvider).isConfigured) {
      return const Chip(
        avatar: Icon(Icons.cloud_off_outlined, size: 18),
        label: Text('Cloud not configured'),
      );
    }
    final account = ref.watch(cloudAccountProvider);
    return account.when(
      loading: () => const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stack) => Tooltip(
        message: error.toString(),
        child: const Icon(Icons.cloud_off_outlined),
      ),
      data: (value) => value == null
          ? FilledButton.tonalIcon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _CloudSignInDialog(),
              ),
              icon: const Icon(Icons.login),
              label: const Text('Sign in'),
            )
          : PopupMenuButton<String>(
              tooltip: 'CycleReady cloud account',
              onSelected: (_) => _confirmSignOut(context, ref),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
              ],
              child: Chip(
                avatar: const Icon(Icons.cloud_done_outlined, size: 18),
                label: Text(value.email),
              ),
            ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of CycleReady?'),
        content: const Text(
          'To protect your health information, signing out removes this '
          'account\'s rides, health records, plans, nutrition, pending uploads '
          'and connected-service credentials from this phone. Cloud records '
          'remain available when you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove local data and sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(secureSignOutControllerProvider).signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Local account data removed. Signed out.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out stopped safely: $error')),
        );
      }
    }
  }
}

class _CloudSignInDialog extends ConsumerStatefulWidget {
  const _CloudSignInDialog();

  @override
  ConsumerState<_CloudSignInDialog> createState() => _CloudSignInDialogState();
}

class _CloudSignInDialogState extends ConsumerState<_CloudSignInDialog> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('CycleReady cloud'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                enabled: !busy,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : _resetPassword,
            child: const Text('Forgot password?'),
          ),
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: busy ? null : () => _submit(create: true),
            child: const Text('Create account'),
          ),
          FilledButton(
            onPressed: busy ? null : () => _submit(create: false),
            child: const Text('Sign in'),
          ),
        ],
      );

  Future<void> _resetPassword() async {
    if (!email.text.contains('@')) {
      setState(() => error = 'Enter your email address first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(cloudAuthRepositoryProvider)
          .requestPasswordReset(email: email.text);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password recovery email sent. Check your inbox.'),
        ),
      );
    } catch (exception) {
      if (mounted) {
        setState(() {
          busy = false;
          error = exception.toString();
        });
      }
    }
  }

  Future<void> _submit({required bool create}) async {
    if (!email.text.contains('@') || password.text.length < 8) {
      setState(() => error = 'Enter a valid email and at least 8 characters.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repository = ref.read(cloudAuthRepositoryProvider);
      if (create) {
        await repository.signUp(email: email.text, password: password.text);
      } else {
        await repository.signIn(email: email.text, password: password.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) {
        setState(() {
          busy = false;
          error = exception.toString();
        });
      }
    }
  }
}
