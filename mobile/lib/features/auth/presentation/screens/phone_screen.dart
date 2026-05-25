import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController(text: '+256 ');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _devLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.post<Map<String, dynamic>>(
        '/v1/auth/dev-login',
        body: {'phone': _ctrl.text.trim().isEmpty ? '+256000000000' : _ctrl.text.trim()},
        fromJson: (d) => d as Map<String, dynamic>,
      );
      await client.saveTokens(
        res['access_token'] as String,
        res['refresh_token'] as String,
      );
      ref.invalidate(authStateProvider);
      if (mounted) context.go('/');
    } catch (_) {
      setState(() => _error = 'Dev login failed. Is the backend running?');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.post<Map<String, dynamic>>(
        '/v1/auth/send-otp',
        body: {'phone': _ctrl.text.trim()},
        fromJson: (d) => d as Map<String, dynamic>,
      );
      final phone = _ctrl.text.trim();
      final devCode = res['dev_code'] as String?;
      if (mounted) context.push('/auth/otp', extra: {'phone': phone, 'devCode': devCode});
    } catch (e) {
      setState(() => _error = 'Could not send code. Check your number and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HapaColors.deep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Image.asset(
                'assets/branding/hapa-logo-dark.png',
                width: 180,
                height: 180,
              ),
              const SizedBox(height: 24),
              Text(
                'Enter your phone number to continue',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  fillColor: const Color(0xFF2A1E10),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Colors.grey.shade800),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Colors.grey.shade800),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: HapaColors.ochre),
                  ),
                  hintText: '+256 700 000 000',
                  hintStyle: TextStyle(color: Colors.grey.shade700),
                  prefixIcon: const Icon(Icons.phone_outlined, color: HapaColors.ochre),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _send,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('SEND CODE'),
                ),
              ),
              const Spacer(flex: 2),
              // Dev-only bypass button — stripped from release builds
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _loading ? null : _devLogin,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: HapaColors.ochre.withValues(alpha: 0.35)),
                      color: HapaColors.ochre.withValues(alpha: 0.07),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 15, color: HapaColors.ochre),
                        const SizedBox(width: 6),
                        Text(
                          'DEV LOGIN  (debug only)',
                          style: TextStyle(
                            color: HapaColors.ochre.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'We send a 6-digit code. No passwords.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
