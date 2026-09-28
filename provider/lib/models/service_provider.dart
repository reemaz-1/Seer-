import 'package:cloud_firestore/cloud_firestore.dart';

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



/// Talks to the database.
class ProviderModel {
  final _firestore = FirebaseFirestore.instance;

  Future<ServiceProviderData?> getProvider(String uid) async {
    final doc = await _firestore.collection('providers').doc(uid).get();
    final map = doc.data();
    if (map == null) return null;
    return ServiceProviderData.fromMap(map);
  }

  Future<void> updateProvider(String uid, Map<String, dynamic> updates) async {
    final allowed = Map<String, dynamic>.from(updates)
      ..remove('status')
      ..remove('createdAt')
      ..remove('role');
    await _firestore.collection('providers').doc(uid).update(allowed);
  }
}