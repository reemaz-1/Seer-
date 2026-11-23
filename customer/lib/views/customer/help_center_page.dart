import 'package:flutter/material.dart';

import '../../models/help_faq.dart';
import '../../theme/app_colors.dart';
import 'contact_support_page.dart';

/// Story #80 — FAQ, with an entry point to Story #81.
class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({
    super.key,
    this.customerEmail = '',
    this.customerName = '',
  });

  final String customerEmail;
  final String customerName;

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _contactSupport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactSupportPage(
          customerEmail: widget.customerEmail,
          customerName: widget.customerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = HelpFaqCatalog.search(_search.text);

    return Scaffold(
      backgroundColor: CustomerColors.background,
      appBar: AppBar(
        title: const Text('مركز المساعدة'),
        foregroundColor: Colors.white,
        backgroundColor: CustomerColors.darkPanel,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
          children: [
            const Text(
              'كيف نقدر نساعدك؟',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: CustomerColors.primaryText,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث في الأسئلة الشائعة',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _search.clear,
                      ),
                filled: true,
                fillColor: CustomerColors.fieldFill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: CustomerColors.cardBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: CustomerColors.cardBorder,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SupportCard(onTap: _contactSupport),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.quiz_outlined, color: CustomerColors.accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'الأسئلة الشائعة',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: CustomerColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (matches.isEmpty)
              _NoSearchResults(onClear: _search.clear)
            else
              ...matches.map(
                (faq) => Padding(
                  key: ValueKey(faq.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FaqTile(faq: faq),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final HelpFaq faq;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CustomerColors.fieldFill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: CustomerColors.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
          iconColor: CustomerColors.accent,
          collapsedIconColor: CustomerColors.secondaryText,
          title: Text(
            faq.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: CustomerColors.primaryText,
            ),
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                faq.answer,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: CustomerColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: CustomerColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 34,
            color: CustomerColors.secondaryText,
          ),
          const SizedBox(height: 10),
          const Text('ما لقينا سؤال يطابق بحثك'),
          const SizedBox(height: 8),
          TextButton(onPressed: onClear, child: const Text('عرض كل الأسئلة')),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CustomerColors.fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: CustomerColors.cardBorder),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(
          Icons.support_agent_rounded,
          color: CustomerColors.accent,
        ),
        title: const Text(
          'تواصل مع الدعم',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: CustomerColors.secondaryText,
        ),
      ),
    );
  }
}
