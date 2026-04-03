import 'package:flutter/material.dart';

import '../config/theme.dart';

Widget buildPawVideoThumb(String path, {double? height}) {
  return Container(
    height: height ?? 120,
    color: PawPartyColors.surfaceVariant,
    child: const Center(
      child: Icon(Icons.play_circle_fill, size: 48, color: PawPartyColors.primary),
    ),
  );
}
