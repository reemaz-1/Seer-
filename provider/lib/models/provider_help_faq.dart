/// Lightweight, offline FAQs for Provider (#80). No Firestore rules required.
class ProviderHelpFaq {
  const ProviderHelpFaq({
    required this.id,
    required this.question,
    required this.answer,
  });

  final String id;
  final String question;
  final String answer;
}

class ProviderHelpFaqCatalog {
  const ProviderHelpFaqCatalog._();

  static const items = <ProviderHelpFaq>[
    ProviderHelpFaq(
      id: 'availability',
      question: 'كيف أغيّر حالة توفري؟',
      answer: 'من الصفحة الرئيسية غيّر حالة التوفر. عند تفعيلها، تأكد أن الموقع مفعّل حتى تتمكن من استقبال الطلبات المناسبة.',
    ),
    ProviderHelpFaq(
      id: 'requests',
      question: 'كيف أستقبل الطلبات؟',
      answer: 'عند توفر طلب مناسب ستظهر تفاصيله في التطبيق. يمكنك مراجعة المعلومات قبل اتخاذ قرار القبول.',
    ),
    ProviderHelpFaq(
      id: 'accept',
      question: 'ماذا لو قَبِل مزود آخر الطلب قبلي؟',
      answer: 'قد لا يعود الطلب متاحًا إذا قبله مزود آخر أولًا. تحقق من قائمة الطلبات المتاحة لمعرفة حالتها.',
    ),
    ProviderHelpFaq(
      id: 'location',
      question: 'لماذا يحتاج التطبيق إلى موقعي؟',
      answer: 'يستخدم موقعك لإظهار الطلبات القريبة وتحديد موقعك خلال الخدمة. تأكد من منح إذن الموقع عند الحاجة.',
    ),
    ProviderHelpFaq(
      id: 'services',
      question: 'كيف أعدّل الخدمات التي أقدمها؟',
      answer: 'من الملف الشخصي، افتح «الخدمات المقدمة» ثم اختر «تعديل».',
    ),
    ProviderHelpFaq(
      id: 'profile',
      question: 'كيف أعدّل بياناتي أو مركبتي؟',
      answer: 'من الملف الشخصي، استخدم «تعديل» في قسم المعلومات الشخصية أو تفاصيل المركبة.',
    ),
    ProviderHelpFaq(
      id: 'complaints',
      question: 'كيف أراجع الشكاوى التي أرسلتها؟',
      answer: 'من الملف الشخصي، افتح «الشكاوى المرسلة».',
    ),
  ];

  static List<ProviderHelpFaq> search(String query) {
    final needle = _normalize(query);
    if (needle.isEmpty) return items;
    return items
        .where(
          (item) =>
              _normalize('${item.question} ${item.answer}').contains(needle),
        )
        .toList(growable: false);
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0640]'), '')
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
