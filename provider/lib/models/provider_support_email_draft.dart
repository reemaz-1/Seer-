/// Provider support mail drafts (Story #81).
/// Opening the email app is not the same as sending a message.
class ProviderSupportEmailDraft {
  const ProviderSupportEmailDraft._();

  static const minMessageLength = 10;
  static const maxMessageLength = 1000;

  static const topics = <String>[
    'مشكلة في استقبال الطلبات',
    'الموقع والتوفر',
    'الحساب والخدمات',
    'استفسار عام',
  ];

  static String? validateMessage(String value) {
    final message = value.trim();
    if (message.isEmpty) return 'اكتب رسالتك أولًا';
    if (message.length < minMessageLength) {
      return 'اكتب 10 أحرف على الأقل لتوضيح طلبك';
    }
    if (message.length > maxMessageLength) {
      return 'الحد الأقصى للرسالة 1000 حرف';
    }
    return null;
  }

  static bool validRecipient(String value) {
    final email = value.trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  static String subject(String topic) => 'SEER Provider | $topic';

  static String body({
    required String topic,
    required String message,
    String providerEmail = '',
    String providerName = '',
  }) {
    final email = providerEmail.trim();
    final name = providerName.trim();
    return 'الموضوع: $topic\n\n'
        '${message.trim()}\n\n'
        'نوع المستخدم: مزود خدمة\n'
        '${name.isNotEmpty ? 'الاسم: $name\n' : ''}'
        '${email.isNotEmpty ? 'البريد للرد: $email\n' : ''}'
        'أُعدّت هذه الرسالة من تطبيق SEER.';
  }

  static String plainText({
    required String topic,
    required String message,
    String providerEmail = '',
    String providerName = '',
  }) =>
      '${subject(topic)}\n\n'
      '${body(topic: topic, message: message, providerEmail: providerEmail, providerName: providerName)}';

  static Uri emailUri({
    required String recipient,
    required String topic,
    required String message,
    String providerEmail = '',
    String providerName = '',
  }) {
    if (!validRecipient(recipient)) {
      throw ArgumentError.value(
        recipient,
        'recipient',
        'Invalid support email',
      );
    }
    final params = <String, String>{
      'subject': subject(topic),
      'body': body(
        topic: topic,
        message: message,
        providerEmail: providerEmail,
        providerName: providerName,
      ),
    };
    // Use encodeComponent rather than Uri(queryParameters:) for mailto.
    final query = params.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
    return Uri(scheme: 'mailto', path: recipient.trim(), query: query);
  }
}
