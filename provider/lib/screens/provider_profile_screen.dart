import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'edit_profile_screen.dart';
import 'edit_vehicle_screen.dart';

const List<String> allServices = ['تعبئة وقود', 'اطارات','سحب','بطارية'];

class ProviderProfileScreen extends StatefulWidget{

  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();

}//end ProviderProfileScreen

class _ProviderProfileScreenState extends State<ProviderProfileScreen>{

  late ServiceProviderData provider;

  @override
  void initState(){
    super.initState();
     provider = ServiceProviderData(
      firstName: 'فيصل ',
      lastName: 'العريني',
      phone: '0591312556',
      email: 'ff444a@icloud.com',
      nationalId: '1234567890',
      vehicle: '2021 , 300 هينو',
      plateNumber: '4211 , ب ت ب',
      licenseNumber:'1234567890',
      rating: 4.5,
      status: 'approved',
      services: ['سحب', 'بطارية'],
    );
  }

  @override
  Widget build(BuildContext contex){
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            child:Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:[
              _buildHeader(provider),
              const SizedBox(height: 16),

              _buildInfoCard(
                title:' المعلومات الشخصية',
                rows: {
                  'الاسم الأول' :provider.firstName,
                  'اسم العائلة' : provider.lastName,
                  'رقم الجوال' :provider.phone,
                  'البريد الإلكتروني' :provider.email,
                  'رقم الهوية': provider.nationalId,
                },//end rows
                onEdit: () async {
                  final updated = await Navigator.push<ServiceProviderData>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(provider: provider),
                    ),
                  );
                  if(updated != null){
                    setState((){
                      provider = updated;
                    });
                  }
                }, // edit the profile page
              ),

              const SizedBox(height: 12),
              _buildInfoCard(
                title: 'تفاصيل المركبة',
                rows: {
                  'المركبة': provider.vehicle,
                  'رقم اللوحة': provider.plateNumber,
                  'رقم الرخصة': provider.licenseNumber,
                },
                onEdit: () async{
                  final updated = await Navigator.push<ServiceProviderData>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditVehicleScreen(provider: provider),
                    ),
                  );
                  if(updated != null){
                    setState((){
                      provider = updated;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),
              _buildServicesCard(provider),

              const SizedBox(height: 12),
              _buildAccountCard(),

            ],
            ),
            ),
          ),
        ),
      ),

    );
  }//end build


  Widget _buildHeader(ServiceProviderData provider){

    return  Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(14),
           ),
           alignment: Alignment.center,
           child: Text(
            provider.firstName.characters.first,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
           ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${provider.firstName} ${provider.lastName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.navy,
                ),
              ),
              Text(
                'مزود الخدمة ',
                style: TextStyle(
                  fontSize:13, color: AppColors.secondaryText
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row (
            children: [
              const Icon(Icons.star, size: 14, color: Color(0xFFF4B942)),
              const SizedBox(width: 4),
              Text(provider.rating.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize:14)),
            ],
          ),
        ),
      ],
    );
  }//end _buildHeader

  Widget _buildInfoCard({
    required String title,
    required Map<String, String> rows,
    required VoidCallback onEdit,
  })//end _bulidInfoCard

  {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children:[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style:const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              GestureDetector(
                onTap: onEdit,
                child: const Text(
                  'تعديل',
                  style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rows.keys.elementAt(i), style:TextStyle(fontSize: 13)),
                  Text(rows.values.elementAt(i), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                ],
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, color: AppColors.cardBorder),
          ],
        ],
      ),
    );
  }

Widget _buildServicesCard(ServiceProviderData provider){
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.card,
      border: Border.all(color: AppColors.cardBorder),
      borderRadius: BorderRadius.circular(16),
    ),

    child : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('الخدمات المقدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for(final s in allServices)
            _buildChip(s, active: provider.services.contains(s)),
          ],
        ),
      ],
    ),
  );

}//end _buildServicesCard

Widget _buildChip(String label, {required bool active}){
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFEAF1FC) : const Color(0xFFF5F6F8),
      border: Border.all(color: active ? AppColors.cardBorder : const Color(0xFFEAEBEF)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: active ? AppColors.blue : const Color(0xFFA6ABB8),
      ),
    ),
  );
}//end _buildChip

Widget _buildAccountCard(){
  return Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      border: Border.all(color: AppColors.cardBorder),
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text(
        'تسجيل الخروج ',
        style: TextStyle(color: Colors.red, fontSize: 15),
      ),
      onTap: () {},
    ),
  );
}//end _buildAccountCard

}//end class ProviderProfileScreen



class ServiceProviderData{
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String nationalId;
  final String vehicle;
  final String plateNumber;
  final String licenseNumber;
  final double rating;
  final String status;
  final List<String> services;


  ServiceProviderData({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.nationalId,
    required this.vehicle,
    required this.plateNumber,
    required this.licenseNumber,
    required this.rating,
    required this.status,
    required this.services,
  });

}//end serviceProviderData
