import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/branded_app_bar.dart';

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  static const Color _primary = Color(0xFF115E66);
  static const Color _accent = Color(0xFF19747E);

  final TextEditingController _codeController = TextEditingController();

  bool _is2FAEnabled = false;
  bool _setupComplete = false;
  bool _loading = false;
  String? _error;
  String? _successMessage;

  String? _secret;
  String? _provisioningUri;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSetup() async {
    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.setup2FA();
      if (mounted) {
        setState(() {
          _secret = result['secret'] as String?;
          _provisioningUri = result['provisioning_uri'] as String?;
          _setupComplete = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleConfirm() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _error = 'Please enter a valid 6-digit code.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.confirm2FA(code);
      if (mounted) {
        setState(() {
          _is2FAEnabled = true;
          _setupComplete = false;
          _secret = null;
          _provisioningUri = null;
          _codeController.clear();
          _successMessage =
              result['message'] as String? ?? '2FA enabled successfully.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleDisable() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _error = 'Please enter a valid 6-digit code to disable 2FA.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.disable2FA(code);
      if (mounted) {
        setState(() {
          _is2FAEnabled = false;
          _codeController.clear();
          _successMessage =
              result['message'] as String? ?? '2FA disabled successfully.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          duration: const Duration(seconds: 2),
          backgroundColor: _primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Two-Factor Authentication',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add an extra layer of security to your account by enabling '
              'two-factor authentication with an authenticator app.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildStatusCard(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildMessageBanner(
                message: _error!,
                color: Colors.red.shade700,
                backgroundColor: Colors.red.shade50,
                icon: Icons.error_outline,
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              _buildMessageBanner(
                message: _successMessage!,
                color: Colors.green.shade700,
                backgroundColor: Colors.green.shade50,
                icon: Icons.check_circle_outline,
              ),
            ],
            if (!_is2FAEnabled && !_setupComplete) ...[
              const SizedBox(height: 24),
              _buildSetupButton(),
            ],
            if (_setupComplete && !_is2FAEnabled) ...[
              const SizedBox(height: 24),
              _buildSetupDetails(),
              const SizedBox(height: 24),
              _buildConfirmSection(),
            ],
            if (_is2FAEnabled) ...[
              const SizedBox(height: 24),
              _buildDisableSection(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _is2FAEnabled
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _is2FAEnabled
              ? Colors.green.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _is2FAEnabled ? Icons.verified_user : Icons.shield_outlined,
            color: _is2FAEnabled ? Colors.green.shade700 : Colors.orange.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2FA Status',
                  style: TextStyle(
                    fontSize: 13,
                    color: _is2FAEnabled
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _is2FAEnabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _is2FAEnabled
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBanner({
    required String message,
    required Color color,
    required Color backgroundColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _handleSetup,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.lock_outline),
        label: Text(_loading ? 'Setting up...' : 'Set Up 2FA'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSetupDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phonelink_setup, color: _accent, size: 22),
              SizedBox(width: 8),
              Text(
                'Authenticator Setup',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '1. Open your authenticator app (e.g. Google Authenticator, Authy).',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 4),
          const Text(
            '2. Add a new account using the secret key or provisioning URI below.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 4),
          const Text(
            '3. Enter the 6-digit code from your authenticator to confirm setup.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          if (_secret != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Secret Key',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ),
            const SizedBox(height: 6),
            _buildCopiableField(_secret!, 'Secret key'),
          ],
          if (_provisioningUri != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Provisioning URI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'You can paste this URI into your authenticator app if it supports manual URI entry.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 6),
            _buildCopiableField(_provisioningUri!, 'Provisioning URI'),
          ],
        ],
      ),
    );
  }

  Widget _buildCopiableField(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _copyToClipboard(value, label),
            icon: const Icon(Icons.copy, size: 20),
            color: _accent,
            tooltip: 'Copy $label',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInput() {
    return TextField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
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
      decoration: InputDecoration(
        hintText: '000000',
        hintStyle: TextStyle(
          color: Colors.grey.shade300,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 8,
          fontFamily: 'monospace',
        ),
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildConfirmSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirm Setup',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the 6-digit code from your authenticator app to complete setup.',
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildCodeInput(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _handleConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm & Enable 2FA'),
          ),
        ],
      ),
    );
  }

  Widget _buildDisableSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'Disable 2FA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Disabling two-factor authentication will make your account less '
            'secure. Enter your current authenticator code to proceed.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildCodeInput(),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loading ? null : _handleDisable,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade400),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red.shade700,
                    ),
                  )
                : const Text('Disable 2FA'),
          ),
        ],
      ),
    );
  }
}
