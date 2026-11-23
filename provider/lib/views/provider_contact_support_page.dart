import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/provider_support_email_draft.dart';
import '../theme/app_colors.dart';

/// #81 - Short contact form. Never claims the message was submitted in SEER.
class ProviderContactSupportPage extends StatefulWidget {
  const ProviderContactSupportPage({
    super.key,
    this.providerEmail = '',
    this.providerName = '',
  });

  final String providerEmail;
  final String providerName;

  @override
  State<ProviderContactSupportPage> createState() =>
      _ProviderContactSupportPageState();
}

class _ProviderContactSupportPageState
    extends State<ProviderContactSupportPage> {
  static const _supportEmail = String.fromEnvironment(
    'SEER_SUPPORT_EMAIL',
    defaultValue: 'supportseer@gmail.com',
  );

  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  String _topic = ProviderSupportEmailDraft.topics.first;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _continue() async {
    if (_busy || _formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    try {
      final uri = ProviderSupportEmailDraft.emailUri(
        recipient: _supportEmail,
        topic: _topic,
        message: _message.text,
        providerEmail: widget.providerEmail,
        providerName: widget.providerName,
      );
      // Launches a mail composer only. Sending is the user's next action.
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showError('تعذّر فتح البريد، حاول مرة أخرى');
    } catch (_) {
      if (mounted) _showError('تعذّر فتح البريد، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تواصل مع الدعم'),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.darkPanel,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
            children: [
              const Text(
                'موضوع الاستفسار',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _topic,
                isExpanded: true,
                decoration: _decoration(),
                items: [
                  for (final topic in ProviderSupportEmailDraft.topics)
                    DropdownMenuItem(value: topic, child: Text(topic)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _topic = value);
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'رسالتك',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _message,
                minLines: 5,
                maxLines: 8,
                maxLength: ProviderSupportEmailDraft.maxMessageLength,
                textInputAction: TextInputAction.newline,
                decoration: _decoration(
                  hint: 'اكتب تفاصيل استفسارك...',
                  hideCounter: true,
                ),
                validator: (value) =>
                    ProviderSupportEmailDraft.validateMessage(value ?? ''),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('فتح البريد لإرسال الرسالة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({String? hint, bool hideCounter = false}) {
    return InputDecoration(
      hintText: hint,
      counterText: hideCounter ? '' : null,
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
