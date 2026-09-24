import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'provider_profile_screen.dart';


class EditProfileScreen extends StatefulWidget{
  final ServiceProviderData provider;

  const EditProfileScreen({super.key, required this.provider});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();

}//end EditProfileScreen

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController nationalIdController;


    final _formKey = GlobalKey<FormState>();

    @override
    void initState(){
      super.initState();
      firstNameController = TextEditingController(text: widget.provider.firstName);
      lastNameController = TextEditingController(text: widget.provider.lastName);
      phoneController = TextEditingController(text: widget.provider.phone);
      emailController = TextEditingController(text: widget.provider.email);
      nationalIdController = TextEditingController(text: widget.provider.nationalId);
    }//end initState

   @override
   void dispose(){
     firstNameController.dispose();
     lastNameController.dispose();
     phoneController.dispose();
     emailController.dispose();
     nationalIdController.dispose();
      super.dispose();
   }//end dispose


  @override
  Widget build(BuildContext contetx){
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('تعديل المعلومات الشخصية'),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الأول',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value){
                    if(value == null || value.trim().isEmpty){
                      return 'الاسم الأول مطلوب';
                    }//end if
                    return null;
                  },//end validator
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العائلة',
                    border: OutlineInputBorder(),
                ),
                  validator: (value){
                   if(value == null || value.trim().isEmpty){
                  return 'اسم العائلة مطلوب';
                }//end if
                 return null;
                 },//end validator
                  ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value){
                    if(value == null || value.trim().isEmpty){
                      return 'رقم الجوال مطلوب';
                    }//end if
                    return null;
                  },//validator
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: emailController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                  ),

                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: nationalIdController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهوية',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                //Button to save changes
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: (){
                    if(_formKey.currentState!.validate()){
                      final updatedProvider = ServiceProviderData(
                        firstName: firstNameController.text,
                        lastName: lastNameController.text,
                        phone : phoneController.text,
                        email : widget.provider.email,
                        nationalId : widget.provider.nationalId,
                        vehicle : widget.provider.vehicle,
                        plateNumberArabic : widget.provider.plateNumberArabic,
                        plateNumberLatin : widget.provider.plateNumberLatin, 
                        vehicleColor: widget.provider.vehicleColor,
                        licenseNumber : widget.provider.licenseNumber,
                        rating : widget.provider.rating,
                        status : widget.provider.status,
                        activeBranches : widget.provider.activeBranches,
                      );
                      Navigator.pop(context, updatedProvider);
                    }//end if
                  },
                  child: const Text(
                    'حفظ التغييرات',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
           ),
        ),
        ),
      ),
    );
  }//end build



}//end _EditProfileScreenState
