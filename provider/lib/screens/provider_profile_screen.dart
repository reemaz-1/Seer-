import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'edit_profile_screen.dart';
import 'edit_vehicle_screen.dart';
import 'edit_services_screen.dart';
import '../services/auth_service.dart';
import '../widgets/logout_button.dart';


const Map<String, List<String>> allServiceBranches = {
  'البطارية': ['شحن', 'تبديل'],
  'الوقود': ['٩١', '٩٥'],
  'الإطارات': ['نفخ', 'تصليح', 'تبديل احتياطي', 'تركيب جديد'],
  'السطحة': ['عادية', 'هيدروليك'],
};

const Map<String, String> _serviceOptionToBranch = {
  'activation'  : 'شحن',
  'replace'     : 'تبديل',
  'petrol91'    : '٩١',
  'petrol95'    : '٩٥',
  'airInflate'  : 'نفخ',
  'patch'       : 'تصليح',
  'spareChange' : 'تبديل احتياطي',
  'newTire'     : 'تركيب جديد',
  'regular'     : 'عادية',
  'hydraulic'   : 'هيدروليك',
};

Set<String> activeBranchesFromServicesOffered(dynamic servicesOffered){
  final Set<String> active = {};
  if(servicesOffered is! Map) return active;

  for(final category in servicesOffered.values){
    if(category is! Map) continue;
    final options = category['options'];
    if(options is! List) continue;

    for(final option in options){
      if(option is! Map) continue;
      if(option['enabled'] == true){
        final branch = _serviceOptionToBranch[option['id']];
        if(branch != null) active.add(branch);
      }//end if
    }//end for
  }//end for
  return active;
}//end activeBranchesFromServicesOffered

const Map<String, Map<String, dynamic>> _serviceCategoryDefinitions = {
  'battery': {
    'label': 'خدمة البطارية',
    'options': [
      {'id': 'activation', 'label': 'تشغيل البطارية (اشتراك)', 'branch': 'شحن'},
      {'id': 'replace', 'label': 'تغيير البطارية', 'branch': 'تبديل'},
    ],
  },
  'fuel': {
    'label': 'التزويد بالوقود',
    'options': [
      {'id': 'petrol91', 'label': 'بنزين 91 (أخضر)', 'branch': '٩١'},
      {'id': 'petrol95', 'label': 'بنزين 95 (أحمر)', 'branch': '٩٥'},
    ],
  },
  'tires': {
    'label': 'خدمة الإطارات',
    'options': [
      {'id': 'airInflate', 'label': 'نفخ الإطار بالهواء', 'branch': 'نفخ'},
      {'id': 'patch', 'label': 'ترقيع الإطار', 'branch': 'تصليح'},
      {'id': 'spareChange', 'label': 'تغيير الإطار الاحتياطي', 'branch': 'تبديل احتياطي'},
      {'id': 'newTire', 'label': 'تغيير الإطار بإطار جديد', 'branch': 'تركيب جديد'},
    ],
  },
  'towing': {
    'label': 'خدمة السطحة',
    'options': [
      {'id': 'regular', 'label': 'سطحة عادية', 'branch': 'عادية'},
      {'id': 'hydraulic', 'label': 'سطحة هيدروليكية', 'branch': 'هيدروليك'},
    ],
  },
};


Map<String, dynamic> servicesOfferedFromActiveBranches(Set<String> activeBranches){
  final Map<String, dynamic> result = {};
  _serviceCategoryDefinitions.forEach((categoryKey, categoryDef){
    result[categoryKey] = {
      'label': categoryDef['label'],
      'options': [
        for (final opt in categoryDef['options'] as List<Map<String, dynamic>>)
          {
            'id': opt['id'],
            'label': opt['label'],
            'enabled': activeBranches.contains(opt['branch']),
          },
      ],
    };
  });
  return result;
}//end servicesOfferedFromActiveBranches

class ProviderProfileScreen extends StatefulWidget{

  const ProviderProfileScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();

}//end ProviderProfileScreen

class _ProviderProfileScreenState extends State<ProviderProfileScreen>{

  late final AuthService _authService;
  ServiceProviderData? provider;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState(){
   super.initState();
   _authService = widget.authService ?? AuthService();
   _loadProvider();
  }

  Future<void> _loadProvider() async{
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try{
      final map = await _authService.getProviderProfile();
      if (!mounted) return;
      if(map != null){
        provider = ServiceProviderData.fromMap(map);
      } else {
        errorMessage = 'المستند غير موجود';
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      errorMessage = error.message;
    } catch(e){
      if (!mounted) return;
      errorMessage = 'تم قطع الاتصال، الرجاء التأكد من اتصالك بالإنترنت';
    }
    setState((){
      isLoading = false;
    });
  }//end _loadProvider

  Future<bool> _saveProviderUpdates(Map<String, dynamic> updates) async{
    try {
      await _authService.updateProviderProfile(updates);
      return mounted;
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return false;
    }
  }//end _saveProviderUpdates
 
  @override
  Widget build(BuildContext contex){

    if(isLoading){
      return const Center(child: CircularProgressIndicator());
    }// end if

    if(errorMessage != null ){
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage!, textAlign: TextAlign.center),
            TextButton(
              onPressed: _loadProvider,
              child: const Text('إعادة المحاولة'),
            ),
            LogoutButton(authService: _authService),
          ],
        ),
      );
    }//end if

    final data = provider!;

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
                    final saved = await _saveProviderUpdates({
                      'firstName' : updated.firstName,
                      'lastName' :updated.lastName,
                      'phone' : updated.phone,
                    });
                    if (!saved || !mounted) return;
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
                    final saved = await _saveProviderUpdates({
                      'vehicleColor' : updated.vehicleColor,
                      'plateNumberArabic' : updated.plateNumberArabic,
                      'plateNumberLatin' : updated.plateNumberLatin,
                      'licenseNumber' : updated.licenseNumber,
                    });
                    if (!saved || !mounted) return;
                    setState((){
                      provider = updated;
                    });
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
                  final saved = await _saveProviderUpdates({
                    'servicesOffered' : servicesOfferedFromActiveBranches(updated.activeBranches),
                   });
                  if (!saved || !mounted) return;
                  setState((){
                    this.provider = updated;
                  });
                }
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



class ServiceProviderData{
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String nationalId;
  final String vehicle;
  final String plateNumberArabic;
  final String plateNumberLatin;
  final String vehicleColor;
  final String licenseNumber;
  final double rating;
  final String status;
  final Set<String> activeBranches;


  ServiceProviderData({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.nationalId,
    required this.vehicle,
    required this.plateNumberArabic,
    required this.plateNumberLatin,
    required this.vehicleColor,
    required this.licenseNumber,
    required this.rating,
    required this.status,
    required this.activeBranches,
  });

  factory ServiceProviderData.fromMap(Map<String, dynamic> map) {

    return ServiceProviderData(
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      nationalId: map['nationalId'] ?? '',
      vehicle: '${map['vehicleBrand'] ?? ''} ${map['vehicleModel'] ?? ''}',
      plateNumberArabic: map['plateNumberArabic'] ?? '',
      plateNumberLatin: map['plateNumberLatin'] ?? '',
      vehicleColor: map['vehicleColor'] ?? '',
      licenseNumber: map['licenseNumber'] ?? '',
      rating: 0.0,
      status: map['status'] ?? '',
      activeBranches: activeBranchesFromServicesOffered(map['servicesOffered']),
    );
  }

}//end serviceProviderData
