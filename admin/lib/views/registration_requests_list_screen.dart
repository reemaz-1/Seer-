import 'package:flutter/material.dart';
import '../controllers/registration_requests_controller.dart';
import '../models/provider_registration_request.dart';
import 'registration_request_detail_screen.dart';

class RegistrationRequestsListScreen extends StatefulWidget {
  const RegistrationRequestsListScreen({super.key});

  @override
  State<RegistrationRequestsListScreen> createState() =>
      _RegistrationRequestsListScreenState();
}

class _RegistrationRequestsListScreenState
    extends State<RegistrationRequestsListScreen> {
  final RegistrationRequestsController _controller =
      RegistrationRequestsController();

  static const Color navy = Color(0xFF0E1B33);
  static const Color accent = Color(0xFF1C63D6);
  static const Color background = Color(0xFFF7F9FC);
  static const Color secondaryText = Color(0xFF6B7385);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: StreamBuilder<List<ProviderRegistrationRequest>>(
          stream: _controller.getRequestsList(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('خطأ: ${snapshot.error}'),
              );
            }

            final requests = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'طلبات تسجيل مزودي الخدمة',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),

                if (requests.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'لا توجد طلبات تسجيل معلقة.',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final r = requests[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE4E8F0),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: accent.withOpacity(0.1),
                              child: Text(
                                r.firstName.isNotEmpty
                                    ? r.firstName[0]
                                    : '؟',
                                style: const TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              '${r.firstName} ${r.lastName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: navy,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            subtitle: Text(
                              '${r.vehicleBrand} ${r.vehicleModel}',
                              style: const TextStyle(
                                color: secondaryText,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: accent,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RegistrationRequestDetailScreen(
                                    requestId: r.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
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
