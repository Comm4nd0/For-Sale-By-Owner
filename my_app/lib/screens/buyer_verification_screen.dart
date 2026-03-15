import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/buyer_verification.dart';
import '../widgets/branded_app_bar.dart';

class BuyerVerificationScreen extends StatefulWidget {
  const BuyerVerificationScreen({super.key});
  @override
  State<BuyerVerificationScreen> createState() => _BuyerVerificationScreenState();
}

class _BuyerVerificationScreenState extends State<BuyerVerificationScreen> {
  List<BuyerVerification> _verifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getBuyerVerifications();
      setState(() {
        _verifications = data.map((d) => BuyerVerification.fromJson(d)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _upload(String type) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    try {
      final api = context.read<ApiService>();
      await api.createBuyerVerification(type, file.path);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded for review')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified': return Colors.green;
      case 'rejected': return Colors.red;
      case 'expired': return Colors.orange;
      default: return Colors.amber;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'verified': return Icons.verified;
      case 'rejected': return Icons.cancel;
      case 'expired': return Icons.timer_off;
      default: return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(title: 'Buyer Verification'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Verify your buyer status to stand out to sellers. Upload proof of funds or mortgage agreement.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ..._verifications.map((v) => Card(
                  child: ListTile(
                    leading: Icon(_statusIcon(v.status), color: _statusColor(v.status)),
                    title: Text(v.verificationTypeDisplay),
                    subtitle: Text(v.status.toUpperCase(), style: TextStyle(color: _statusColor(v.status), fontWeight: FontWeight.bold, fontSize: 12)),
                    trailing: v.isValid ? const Chip(label: Text('Valid', style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Colors.green) : null,
                  ),
                )),
                const SizedBox(height: 24),
                const Text('Upload Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _uploadCard('Mortgage Agreement in Principle', 'mortgage_aip', Icons.account_balance),
                _uploadCard('Proof of Funds', 'proof_of_funds', Icons.savings),
                _uploadCard('ID Verification', 'id_verification', Icons.badge),
              ],
            ),
    );
  }

  Widget _uploadCard(String label, String type, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF115E66)),
        title: Text(label),
        subtitle: const Text('Tap to upload document'),
        trailing: const Icon(Icons.upload_file),
        onTap: () => _upload(type),
      ),
    );
  }
}
