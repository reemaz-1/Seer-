import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colors of the order chat, mapped to the CUSTOMER theme.
class ChatColors {
  /// Prevents instantiation; takes no inputs and creates no public object.
  ChatColors._();

  static const pageBackground = CustomerColors.fieldFill;
  static const appBar = CustomerColors.darkPanel;
  static const appBarText = Colors.white;
  static const mineBubble = CustomerColors.accent;
  static const mineText = Colors.white;
  static const mineMeta = Color(0xCCFFFFFF);
  static const readTick = Color(0xFF7DE3A0);
  static const theirsBubble = Colors.white;
  static const theirsText = CustomerColors.primaryText;
  static const border = CustomerColors.cardBorder;
  static const secondaryText = CustomerColors.secondaryText;
  static const accent = CustomerColors.accent;
  static const warning = AppStatusColors.warning;
  static const inputFill = CustomerColors.fieldFill;
  static const dayPill = CustomerColors.cardBorder;
}