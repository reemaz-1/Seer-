import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'provider_profile_screen.dart';
import '../widgets/plate_number_field.dart';


class EditVehicleScreen extends StatefulWidget{
  final ServiceProviderData provider;

  const EditVehicleScreen({super.key, required this.provider});

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();

}//end EditVehicleScreen

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  late TextEditingController vehicleController;
  late TextEditingController colorController;
  late TextEditingController licenseController;
  late String _initialPlateDigits;
  late String _initialPlateArabicLetters;
  bool _plateError = false;

  final _plateFieldKey = GlobalKey<PlateNumberFieldState>();
  final _formKey = GlobalKey<FormState>();

    @override
    void initState(){
      super.initState();
      vehicleController = TextEditingController(text: widget.provider.vehicle);
      colorController = TextEditingController(text: widget.provider.vehicleColor);
      licenseController = TextEditingController(text: widget.provider.licenseNumber);

      final arabicParts = widget.provider.plateNumberArabic.trim().split(' ');
      _initialPlateDigits = arabicParts.isNotEmpty ? arabicParts[0] : '';
      _initialPlateArabicLetters = arabicParts.length > 1 ? arabicParts[1] : '';
    }//end initState

   @override
   void dispose(){
     vehicleController.dispose();
     colorController.dispose();
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
                  controller: colorController,
                  decoration: const InputDecoration(
                    labelText: 'لون المركبة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value){
                    if(value==null || value.trim().isEmpty){
                      return 'لون المركبة مطلوب' ;
                    }//end if
                    return null;
                  },//end validator
                ),

                const SizedBox(height: 14),

                  PlateNumberField(
                  key: _plateFieldKey,
                  navy: AppColors.navy,
                  initialDigits: _initialPlateDigits,
                  initialArabicLetters: _initialPlateArabicLetters,
                ),
                if(_plateError)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'رقم اللوحة مطلوب',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
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
                    final plateValue = _plateFieldKey.currentState!.value;
                    setState((){
                      _plateError = !plateValue.isValid;
                    });

                    if(_formKey.currentState!.validate() && plateValue.isValid){
                      final updatedProvider = ServiceProviderData(
                        firstName: widget.provider.firstName,
                        lastName: widget.provider.lastName,
                        phone : widget.provider.phone,
                        email : widget.provider.email,
                        nationalId : widget.provider.nationalId,
                        vehicle : vehicleController.text,
                        plateNumberArabic: '${plateValue.digits} ${plateValue.arabicLetters}',
                        plateNumberLatin: '${plateValue.digits} ${plateValue.englishLetters}',
                        vehicleColor : colorController.text,
                        licenseNumber : licenseController.text,
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

}//end _EditVehicleScreenState
