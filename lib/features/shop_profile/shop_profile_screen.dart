import 'package:flutter/material.dart';

import '../../services/shop_profile_service.dart';
import '../dashboard/dashboard_screen.dart';

class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({super.key, this.firstSetup = false});

  final bool firstSetup;

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _receiptFooterController = TextEditingController(
    text: 'ස්තුතියි! නැවත පැමිණෙන්න.',
  );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ShopProfileService.instance.getProfile();

    if (!mounted || profile == null) {
      return;
    }

    _shopNameController.text = profile['shop_name'] as String? ?? '';

    _phoneController.text = profile['phone'] as String? ?? '';

    _addressController.text = profile['address'] as String? ?? '';

    _receiptFooterController.text =
        profile['receipt_footer'] as String? ?? 'ස්තුතියි! නැවත පැමිණෙන්න.';
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ShopProfileService.instance.saveProfile(
        shopName: _shopNameController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        receiptFooter: _receiptFooterController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('සාප්පුවේ තොරතුරු සාර්ථකව සුරකින ලදී.')),
      );

      if (widget.firstSetup) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('තොරතුරු සුරැකීමට නොහැකි විය: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstSetup ? 'සාප්පුවේ තොරතුරු' : 'සාප්පු තොරතුරු'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.firstSetup) ...[
                    const Text(
                      'ඔබගේ සාප්පුවේ තොරතුරු ඇතුළත් කරන්න.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  TextFormField(
                    controller: _shopNameController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('සාප්පුවේ නම'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'සාප්පුවේ නම ඇතුළත් කරන්න';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('දුරකථන අංකය'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('සාප්පුවේ ලිපිනය'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _receiptFooterController,
                    maxLines: 2,
                    decoration: _inputDecoration('බිල්පතේ අවසාන පණිවිඩය'),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('තොරතුරු සුරකින්න'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
