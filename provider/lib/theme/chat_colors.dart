import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colors of the order chat, mapped to the PROVIDER theme.
class ChatColors {
  /// Prevents instantiation; takes no inputs and creates no public object.
  ChatColors._();

  static const pageBackground = AppColors.background;
  static const appBar = AppColors.background;
  static const appBarText = AppColors.navy;
  static const mineBubble = AppColors.accent;
  static const mineText = Colors.white;
  static const mineMeta = Color(0xCCFFFFFF);
  static const readTick = Color(0xFF7DE3A0);
  static const theirsBubble = Colors.white;
  static const theirsText = AppColors.navy;
  static const border = AppColors.cardBorder;
  static const secondaryText = AppColors.secondaryText;
  static const accent = AppColors.accent;
  static const warning = AppColors.warning;
  static const inputFill = AppColors.background;
  static const dayPill = AppColors.cardBorder;
}