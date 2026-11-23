/// FAQ content for SEER Customer (Story #80).
/// Kept local so Help Center does not require any Firestore permissions.
class HelpFaq {
  const HelpFaq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final String id;
  final String category;
  final String question;
  final String answer;
}

class HelpFaqCatalog {
  const HelpFaqCatalog._();

  static const items = <HelpFaq>[
    HelpFaq(
      id: 'request',
      category: 'الطلبات',
      question: 'كيف أطلب خدمة لمركبتي؟',
      answer: 'من الصفحة الرئيسية، اختَر نوع الخدمة والخيار المناسب، ثم حدّد مركبتك وموقعها وراجع تفاصيل الطلب قبل التأكيد.',
    ),
    HelpFaq(
      id: 'location',
      category: 'الموقع',
      question: 'كيف أحدد موقع المركبة؟',
      answer: 'افتح خريطة تحديد الموقع، وحرّك العلامة إلى موقع مركبتك، ثم اضغط «تأكيد الموقع».',
    ),
    HelpFaq(
      id: 'providers',
      category: 'الموقع',
      question: 'ماذا لو لم يظهر مزود خدمة قريب؟',
      answer: 'قد لا يتوفر مزود مناسب بالقرب من موقع مركبتك حاليًا. تأكد من تحديد الموقع الصحيح، ثم حاول مرة أخرى لاحقًا.',
    ),
    HelpFaq(
      id: 'track',
      category: 'الطلبات',
      question: 'كيف أتابع حالة طلبي؟',
      answer:
          'افتح قسم الطلبات، ثم اختر طلبك لعرض حالته والتحديثات المتاحة له.',
    ),
    HelpFaq(
      id: 'cancel',
      category: 'الطلبات',
      question: 'كيف ألغي الطلب؟',
      answer: 'افتح تفاصيل الطلب. إذا كان الإلغاء متاحًا لحالته، ستجد خيار الإلغاء هناك.',
    ),
    HelpFaq(
      id: 'vehicles',
      category: 'الحساب',
      question: 'كيف أضيف مركبة أو أعدل بياناتها؟',
      answer: 'من الملف الشخصي، افتح «مركباتي» لإضافة مركبة أو إدارة بيانات مركباتك.',
    ),
    HelpFaq(
      id: 'complaint',
      category: 'الدعم',
      question: 'كيف أرسل شكوى على طلب؟',
      answer: 'افتح تفاصيل الطلب. إذا كان الطلب مؤهلًا لتقديم شكوى، ستظهر لك إمكانية إرسالها من هناك. يمكنك متابعة الشكاوى من الملف الشخصي.',
    ),
    HelpFaq(
      id: 'contact',
      category: 'الدعم',
      question: 'كيف أتواصل مع فريق الدعم؟',
      answer: 'من مركز المساعدة اضغط «تواصل مع الدعم»، وحدد موضوع استفسارك واكتب رسالتك.',
    ),
  ];

  /// Arabic-friendly matching of questions, answers and category labels.
  static List<HelpFaq> search(String query) {
    final needle = _normalize(query);
    if (needle.isEmpty) return items;
    return items
        .where((item) {
          final text = _normalize(
            '${item.question} ${item.answer} ${item.category}',
          );
          return text.contains(needle);
        })
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
