import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'edit_profile_screen.dart';
import 'edit_vehicle_screen.dart';
import 'edit_services_screen.dart';
import '../services/auth_service.dart';
import '../widgets/logout_button.dart';
import '../models/service_provider.dart';
import '../controllers/provider_profile_controller.dart';

export '../models/service_provider.dart';




class ProviderProfileScreen extends StatefulWidget{

  const ProviderProfileScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();

}//end ProviderProfileScreen

class _ProviderProfileScreenState extends State<ProviderProfileScreen>{

  late final AuthService _authService;
  late final ProviderProfileController _controller;

    @override
  void initState(){
   super.initState();
   _authService = widget.authService ?? AuthService();
   _controller = ProviderProfileController()..addListener(_onControllerChanged);
   _loadProvider();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

    Future<void> _loadProvider() async{
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    await _controller.load(uid);
  }//end _loadProvider

    Future<void> _saveProviderUpdates(Map<String, dynamic> updates, ServiceProviderData updated) async{
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final error = await _controller.saveUpdates(uid, updates, updated);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }//end _saveProviderUpdates
 
  @override
  Widget build(BuildContext contex){

        if(_controller.isLoading){
      return const Center(child: CircularProgressIndicator());
    }// end if

    if(_controller.provider == null){
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_controller.errorMessage ?? 'حدث خطأ غير متوقع', textAlign: TextAlign.center),
            TextButton(
              onPressed: _loadProvider,
              child: const Text('إعادة المحاولة'),
            ),
            LogoutButton(authService: _authService),
          ],
        ),
      );
    }//end if

    final data = _controller.provider!;

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
              _buildHeader(data),
              const SizedBox(height: 16),

              _buildInfoCard(
                title:' المعلومات الشخصية',
                rows: {
                  'الاسم الأول' :data.firstName,
                  'اسم العائلة' : data.lastName,
                  'رقم الجوال' :data.phone,
                  'البريد الإلكتروني' :data.email,
                  'رقم الهوية': data.nationalId,
                },//end rows
                onEdit: () async {
                  final updated = await Navigator.push<ServiceProviderData>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(provider: data),
                    ),
                  );
                  
                  if(updated != null && mounted){
                    await _saveProviderUpdates({
                      'firstName' : updated.firstName,
                      'lastName' :updated.lastName,
                      'phone' : updated.phone,
                    }, updated);
                  }
                }, // edit the profile page
              ),

              const SizedBox(height: 12),
              _buildInfoCard(
                title: 'تفاصيل المركبة',
                rows: {
                  'المركبة': data.vehicle,
                  'لون المركبة' :data.vehicleColor,
                  'رقم اللوحة (عربي)': data.plateNumberArabic,
                  'رقم اللوحة (لاتيني)': data.plateNumberLatin,
                  'رقم الرخصة': data.licenseNumber,
                },
                onEdit: () async{
                  final updated = await Navigator.push<ServiceProviderData>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditVehicleScreen(provider: data),
                    ),
                  );        

                  if(updated != null && mounted){
  await _saveProviderUpdates({
    'vehicleBrand' : updated.vehicleBrand,
    'vehicleModel' : updated.vehicleModel,
    'vehicleColor' : updated.vehicleColor,
    'plateNumberArabic' : updated.plateNumberArabic,
    'plateNumberLatin' : updated.plateNumberLatin,
    'licenseNumber' : updated.licenseNumber,
  }, updated);
}
                },
              ),

              const SizedBox(height: 12),
              _buildServicesCard(data),

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
            provider.firstName.isEmpty ? '؟' : provider.firstName.characters.first,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      rows.keys.elementAt(i),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      rows.values.elementAt(i),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, color: AppColors.cardBorder),
          ],
        ],
      ),
    );
  }//end _buildInfoCard


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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('الخدمات المقدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            GestureDetector(
              onTap: () async {
                final updated = await Navigator.push<ServiceProviderData>(
                  context,
                  MaterialPageRoute(
                    builder : (context) => EditServicesScreen(provider: provider),
                  ),
                );           

                 if(updated != null && mounted){
                  await _saveProviderUpdates({
                    'servicesOffered' : servicesOfferedFromActiveBranches(updated.activeBranches),
                   }, updated);
                }//end if
              },
              child: const Text(
                'تعديل',
                style : TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold, fontSize: 14),  
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        for(var i=0 ; i<allServiceBranches.length; i++) ...[
          Text(
            allServiceBranches.keys.elementAt(i),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryText),
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing : 8,
            runSpacing: 8,
            children: [
              for (final branch in allServiceBranches.values.elementAt(i))
              _buildChip(
                branch,
                active: provider.activeBranches.contains(branch),
              ),

            ],
          ),

          if(i != allServiceBranches.length -1)
            const SizedBox(height: 14),
        ]
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
  return Material(
    color: AppColors.card,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.cardBorder),
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text(
        'تسجيل الخروج ',
        style: TextStyle(color: Colors.red, fontSize: 15),
      ),
      onTap: () => LogoutButton.confirm(context, authService: _authService),
    ),
  );
}//end _buildAccountCard

}//end class ProviderProfileScreen



