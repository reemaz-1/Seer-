import 'package:flutter/material.dart';
import '../controllers/registration_requests_controller.dart';
import '../models/provider_registration_request.dart';

class RegistrationRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const RegistrationRequestDetailScreen({super.key, required this.requestId});

  @override
  State<RegistrationRequestDetailScreen> createState() =>
      _RegistrationRequestDetailScreenState();
}

class _RegistrationRequestDetailScreenState
    extends State<RegistrationRequestDetailScreen> {
  final RegistrationRequestsController _controller =
      RegistrationRequestsController();

  static const Color navy = Color(0xFF0E1B33);
  static const Color accent = Color(0xFF1C63D6);
  static const Color secondaryText = Color(0xFF6B7385);
  static const Color background = Color(0xFFF7F9FC);

  bool _isProcessing = false;

  Widget _sectionCard({required String title, required List<Widget> rows}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: secondaryText, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: navy,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceCategory(String category, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            category,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            items.join('، '),
            style: const TextStyle(color: secondaryText, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'مقبول';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'مرفوض';
        break;
      default:
        color = Colors.orange;
        label = 'قيد المراجعة';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _handleApprove() async {
    setState(() => _isProcessing = true);
    try {
      await _controller.approveRequest(widget.requestId);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول الطلب بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    setState(() => _isProcessing = true);
    try {
      await _controller.rejectRequest(widget.requestId);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('تفاصيل الطلب'),
        ),
        body: FutureBuilder<ProviderRegistrationRequest?>(
          future: _controller.getRequestDetails(widget.requestId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return const Center(child: Text('الطلب غير موجود.'));
            }
            final r = snapshot.data!;
            final isPending = r.status == 'pending';
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${r.firstName} ${r.lastName}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: navy,
                              ),
                            ),
                            _statusBadge(r.status),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _sectionCard(
                          title: 'المعلومات الشخصية',
                          rows: [
                            _row('الاسم الأول', r.firstName),
                            _row('اسم العائلة', r.lastName),
                            _row('الهوية / الإقامة', r.nationalId),
                            _row('رقم الجوال', r.phone),
                            _row('البريد الإلكتروني', r.email),
                          ],
                        ),
                        _sectionCard(
                          title: 'بيانات المركبة',
                          rows: [
                            _row('نوع المركبة', r.vehicleType),
                            _row('الماركة', r.vehicleBrand),
                            _row('الموديل', r.vehicleModel),
                            _row('سنة الصنع', r.vehicleYear),
                            _row('رقم اللوحة', r.plateNumber),
                            _row('رقم الرخصة', r.licenseNumber),
                          ],
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE4E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'الخدمات المقدمة',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: navy,
                                ),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 12),
                              if (r.servicesByCategory.isEmpty)
                                const Text(
                                  '-',
                                  style: TextStyle(color: secondaryText),
                                  textAlign: TextAlign.right,
                                )
                              else
                                ...r.servicesByCategory.entries
                                    .map((entry) => _serviceCategory(
                                          entry.key,
                                          entry.value,
                                        )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isPending)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: const Color(0xFFE4E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _isProcessing ? null : _handleReject,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD32F2F),
                                side: const BorderSide(
                                  color: Color(0xFFD32F2F),
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('رفض'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isProcessing ? null : _handleApprove,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('قبول'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}