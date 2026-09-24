import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'provider_profile_screen.dart';


class EditServicesScreen extends StatefulWidget{
  final ServiceProviderData provider;

  const EditServicesScreen({super.key, required this.provider});

  @override
  State<EditServicesScreen> createState() => _EditServicesScreenState();

}//end EditServicesScreen

class _EditServicesScreenState extends State<EditServicesScreen> {
  late Set<String> selectedBranches;

  @override
  void initState(){
    super.initState();
    selectedBranches = Set<String>.from(widget.provider.activeBranches);
  }//end initState

  void _toggleBranch(String branch){
    setState((){
      if(selectedBranches.contains(branch)){
        selectedBranches.remove(branch);
      } else {
        selectedBranches.add(branch);
      }
    });
  }//end _toggleBranch

  @override
  Widget build(BuildContext context){
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('تعديل الخدمات المقدمة'),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final category in allServiceBranches.keys) ...[
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final branch in allServiceBranches[category]!)
                        _buildSelectableChip(
                          branch,
                          active: selectedBranches.contains(branch),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: (){
                    final updatedProvider = ServiceProviderData(
                      firstName: widget.provider.firstName,
                      lastName: widget.provider.lastName,
                      phone: widget.provider.phone,
                      email: widget.provider.email,
                      nationalId: widget.provider.nationalId,
                      vehicle: widget.provider.vehicle,
                      plateNumberArabic : widget.provider.plateNumberArabic,
                      plateNumberLatin : widget.provider.plateNumberLatin,
                      vehicleColor : widget.provider.vehicleColor,
                      licenseNumber: widget.provider.licenseNumber,
                      rating: widget.provider.rating,
                      status: widget.provider.status,
                      activeBranches: selectedBranches,
                    );
                    Navigator.pop(context, updatedProvider);
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
    );
  }//end build

  Widget _buildSelectableChip(String branch, {required bool active}){
    return GestureDetector(
      onTap: () => _toggleBranch(branch),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF1FC) : const Color(0xFFF5F6F8),
          border: Border.all(color: active ? AppColors.cardBorder : const Color(0xFFEAEBEF)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          branch,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: active ? AppColors.blue : const Color(0xFFA6ABB8),
          ),
        ),
      ),
    );
  }//end _buildSelectableChip

}//end _EditServicesScreenState
