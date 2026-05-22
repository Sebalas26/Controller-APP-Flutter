import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key, required this.userDetails});

  final String userDetails;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          userDetails,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
