import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String? devCode;
  const OtpScreen({super.key, required this.phone, this.devCode});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  String get _otp => _ctrls.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    if (widget.devCode != null && widget.devCode!.length == 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (var i = 0; i < 6; i++) {
          _ctrls[i].text = widget.devCode![i];
        }
        setState(() {});
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _verify();
        });
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onDigit(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otp.length == 6) _verify();
  }

  Future<void> _verify() async {
    if (_otp.length < 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.post<Map<String, dynamic>>(
        '/v1/auth/verify-otp',
        body: {'phone': widget.phone, 'code': _otp},
        fromJson: (d) => d as Map<String, dynamic>,
      );
      await client.saveTokens(
        res['access_token'] as String,
        res['refresh_token'] as String,
      );
      ref.invalidate(authStateProvider);
      if (mounted) context.go('/');
    } catch (_) {
      setState(() => _error = 'Invalid code. Please try again.');
      for (final c in _ctrls) c.clear();
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HapaColors.deep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: HapaColors.ochre,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter code',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sent to ${widget.phone}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              if (widget.devCode != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1E10),
                    border: Border.all(color: HapaColors.ochre.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.developer_mode, size: 14, color: HapaColors.ochre),
                      const SizedBox(width: 8),
                      Text(
                        'Dev code: ${widget.devCode} (auto-filled)',
                        style: const TextStyle(
                          color: HapaColors.ochre,
                          fontSize: 12,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _DigitBox(
                  controller: _ctrls[i],
                  focusNode: _focusNodes[i],
                  onChanged: (v) => _onDigit(i, v),
                  autofocus: i == 0,
                )),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ],
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: HapaColors.ochre))
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _otp.length == 6 ? _verify : null,
                    child: const Text('VERIFY CODE'),
                  ),
                ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Wrong number? Go back',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onChanged;
  final bool autofocus;

  const _DigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          counterText: '',
          fillColor: const Color(0xFF2A1E10),
          filled: true,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFF3A2E20)),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFF3A2E20)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: HapaColors.ochre, width: 2),
          ),
        ),
      ),
    );
  }
}
