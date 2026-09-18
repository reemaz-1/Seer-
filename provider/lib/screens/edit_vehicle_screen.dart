import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'provider_profile_screen.dart';


class EditVehicleScreen extends StatefulWidget{
  final ServiceProviderData provider;

  const EditVehicleScreen({super.key, required this.provider});

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();

}//end EditVehicleScreen

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  late TextEditingController vehicleController;
  late TextEditingController plateController;
  late TextEditingController licenseController;


    final _formKey = GlobalKey<FormState>();

    @override
    void initState(){
      super.initState();
      vehicleController = TextEditingController(text: widget.provider.vehicle);
      plateController = TextEditingController(text: widget.provider.plateNumber);
      licenseController = TextEditingController(text: widget.provider.licenseNumber);
    }//end initState

   @override
   void dispose(){
     vehicleController.dispose();
     plateController.dispose();
     licenseController.dispose();
      super.dispose();
   }//end dispose


  @override
  Widget build(BuildContext contetx){
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('تعديل تفاصيل المركبة'),
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
                  controller: vehicleController,
                  decoration: const InputDecoration(
                    labelText: 'المركبة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value){
                    if(value == null || value.trim().isEmpty){
                      return 'اسم المكبة مطلوب';
                    }//end if
                    return null;
                  },//end validator
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: 'رقم اللوحة',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value){
                    if(value == null || value.trim().isEmpty){
                      return 'رقم اللوحة مطلوب';
                    }//end if
                    return null;
                  },//validator
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: licenseController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'رقم الرخصة',
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
                        firstName: widget.provider.firstName,
                        lastName: widget.provider.lastName,
                        phone : widget.provider.phone,
                        email : widget.provider.email,
                        nationalId : widget.provider.nationalId,
                        vehicle : vehicleController.text,
                        plateNumber : plateController.text,
                        licenseNumber : licenseController.text,
                        rating : widget.provider.rating,
                        status : widget.provider.status,
                        services : widget.provider.services,
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



}//end _EditVehicleScreenState
