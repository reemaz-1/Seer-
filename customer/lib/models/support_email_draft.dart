/// Support mail drafts (Story #81).
/// Opening the email app is not the same as sending a message.
class SupportEmailDraft {
  const SupportEmailDraft._();

  static const minMessageLength = 10;
  static const maxMessageLength = 1000;

  static const topics = <String>[
    'استفسار عن خدمة',
    'مشكلة في الطلب',
    'الحساب والمركبات',
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

  static String subject(String topic) => 'SEER | $topic';

  static String body({
    required String topic,
    required String message,
    String customerEmail = '',
    String customerName = '',
  }) {
    final email = customerEmail.trim();
    final name = customerName.trim();
    return 'الموضوع: $topic\n\n'
        '${message.trim()}\n\n'
        'نوع المستخدم: عميل\n'
        '${name.isNotEmpty ? 'الاسم: $name\n' : ''}'
        '${email.isNotEmpty ? 'البريد للرد: $email\n' : ''}'
        'أُعدّت هذه الرسالة من تطبيق SEER.';
  }

  static String plainText({
    required String topic,
    required String message,
    String customerEmail = '',
    String customerName = '',
  }) =>
      '${subject(topic)}\n\n'
      '${body(topic: topic, message: message, customerEmail: customerEmail, customerName: customerName)}';

  static Uri emailUri({
    required String recipient,
    required String topic,
    required String message,
    String customerEmail = '',
    String customerName = '',
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
        customerEmail: customerEmail,
        customerName: customerName,
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
