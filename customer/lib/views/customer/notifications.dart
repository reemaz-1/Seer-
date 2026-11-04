import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1B33),
        foregroundColor: Colors.white,
        title: const Text('الإشعارات'),
      ),
      body: uid == null
          ? const Center(child: Text('لا توجد إشعارات حالياً'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('notifications')
                  .where('recipientId', isEqualTo: uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('تعذر تحميل الإشعارات'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.toList()
                  ..sort((a,b) {
                    final aa = a.data()['createdAt'] as Timestamp?;
                    final bb = b.data()['createdAt'] as Timestamp?;
                    return (bb?.millisecondsSinceEpoch ?? 0).compareTo(aa?.millisecondsSinceEpoch ?? 0);
                  });
                if (docs.isEmpty) {
                  return const Center(child: Text('لا توجد إشعارات حالياً'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    return ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text((data['title'] ?? '').toString(), textDirection: TextDirection.rtl),
                      subtitle: Text((data['body'] ?? '').toString(), textDirection: TextDirection.rtl),
                      onTap: () => d.reference.update({'read': true}),
                    );
                  },
                );
              },
            ),
    );
  }
}
