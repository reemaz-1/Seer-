import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'screens/provider_profile_screen.dart';
import 'screens/edit_profile_screen.dart';

void main(){
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ProviderProfileScreen(),
  ));
}//end main