import 'package:flutter/material.dart';

/// Color roles for the CUSTOMER app — "Icon Navy" theme.
/// Values taken directly from the Seer color reference table.
class CustomerColors {
  static const background = Color(0xFFFFFFFF);
  static const darkPanel = Color(0xFF0E1B33); // header / dark panel
  static const accent = Color(0xFF1C63D6);
  static const cardBorder = Color(0xFFE4E8F0);
  static const primaryText = Color(0xFF0E1B33);
  static const secondaryText = Color(0xFF6B7385);
}

/// Color roles for the SERVICE PROVIDER app — "Fleet Blue" theme.
/// Values taken directly from the Seer color reference table.
class ProviderColors {
  static const background = Color(0xFFF1F4FA);
  static const darkPanel = Color(0xFF0E1B33); // used for text/icons only
  static const accent = Color(0xFF1C63D6);
  static const cardBorder = Color(0xFFDCE6F5);
  static const primaryText = Color(0xFF0E1B33);
  static const secondaryText = Color(0xFF69728C);
}

/// Semantic / status colors shared by both apps.
///
/// NOTE: you listed extra swatch names (Daylight Red, Daylight Green,
/// Steel Graphite, Daylight Steel, Navy Ink + Amber, Navy Sky, Navy Slate,
/// Beige Navy, Brand Navy) but no hex codes for them. The values below are
/// reasonable placeholders — send me the exact hex codes and I'll swap
/// them in.
class AppStatusColors {
  static const success = Color(0xFF2E7D32); // placeholder for "Daylight Green"
  static const error = Color(0xFFC62828); // placeholder for "Daylight Red"
  static const warning = Color(0xFFFFA000); // placeholder for "Amber"
  static const neutralGraphite = Color(0xFF37474F); // placeholder for "Steel Graphite"
}
