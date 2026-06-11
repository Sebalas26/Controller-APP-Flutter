import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/vender_models.dart';

Future<bool?> showVenderCustomerKeyDialog(
  BuildContext context,
  VenderPersonRemoteData result,
) {
  final message = result.message.trim().isNotEmpty
      ? result.message.trim()
      : 'El numero ingresado ya esta asociado a un numero de identificacion.';
  final conflictCount = result.conflicts.length;
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Numero ya registrado',
          style: TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (conflictCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Clientes en conflicto: $conflictCount',
                style: const TextStyle(
                  color: Color(0xFF727272),
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Quieres continuar con la admision?',
              style: TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.black,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Continuar'),
          ),
        ],
      );
    },
  );
}
