import 'package:flutter/material.dart';

import '../models/provider_help_faq.dart';
import '../theme/app_colors.dart';
import 'provider_contact_support_page.dart';

/// Provider #80 FAQ with a direct path to #81 support.
class ProviderHelpCenterPage extends StatefulWidget {
  const ProviderHelpCenterPage({
    super.key,
    this.providerEmail = '',
    this.providerName = '',
  });

  final String providerEmail;
  final String providerName;

  @override
  State<ProviderHelpCenterPage> createState() => _ProviderHelpCenterPageState();
}

class _ProviderHelpCenterPageState extends State<ProviderHelpCenterPage> {
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
        builder: (_) => ProviderContactSupportPage(
          providerEmail: widget.providerEmail,
          providerName: widget.providerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = ProviderHelpFaqCatalog.search(_search.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('مركز المساعدة'),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.darkPanel,
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
                color: AppColors.navy,
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
                fillColor: AppColors.fieldFill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SupportCard(onTap: _contactSupport),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.quiz_outlined, color: AppColors.accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'الأسئلة الشائعة',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: AppColors.navy,
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

  final ProviderHelpFaq faq;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldFill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
          iconColor: AppColors.accent,
          collapsedIconColor: AppColors.secondaryText,
          title: Text(
            faq.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
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
                  color: AppColors.secondaryText,
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
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 34,
            color: AppColors.secondaryText,
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
      color: AppColors.fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(
          Icons.support_agent_rounded,
          color: AppColors.accent,
        ),
        title: const Text(
          'تواصل مع الدعم',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}
