import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
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
              onSelected: (_) =>
                  ref.read(cloudAuthRepositoryProvider).signOut(),
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
