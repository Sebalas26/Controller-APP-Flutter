import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/vender_models.dart';

Future<VenderRestrictiveListAction?> showVenderRestrictiveListSheet(
  BuildContext context, {
  required VenderRestrictiveListResult result,
  required String senderName,
  required String recipientName,
}) {
  return showModalBottomSheet<VenderRestrictiveListAction>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _RestrictiveListSheet(
        result: result,
        senderName: senderName,
        recipientName: recipientName,
      );
    },
  );
}

class _RestrictiveListSheet extends StatelessWidget {
  const _RestrictiveListSheet({
    required this.result,
    required this.senderName,
    required this.recipientName,
  });

  final VenderRestrictiveListResult result;
  final String senderName;
  final String recipientName;

  @override
  Widget build(BuildContext context) {
    final title = result.senderHasDebts
        ? 'Remitente en lista restrictiva'
        : 'Destinatario en lista restrictiva';
    final description = _description();
    final debts = result.senderHasDebts
        ? result.sender.debts
        : result.validRecipientDebts;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFEFEFE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(VenderRestrictiveListAction.cancelSale),
                  icon: const Icon(Icons.close, color: AppColors.black),
                  tooltip: 'Cerrar',
                ),
              ),
              Icon(
                result.recipientHasRestriction
                    ? Icons.block_outlined
                    : Icons.warning_amber_rounded,
                color: result.recipientHasRestriction
                    ? const Color(0xFFC62828)
                    : const Color(0xFFF57F17),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF424242),
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              if (debts.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DebtList(debts: debts.take(5).toList()),
              ],
              const SizedBox(height: 18),
              ..._actions(context),
            ],
          ),
        ),
      ),
    );
  }

  String _description() {
    if (result.senderHasDebts) {
      final name = result.sender.name.trim().isNotEmpty
          ? result.sender.name.trim()
          : senderName;
      return '$name tiene envios al cobro sin pagar. Para continuar la admision se debe cambiar la forma de pago a contado.';
    }
    final name = result.recipient.name.trim().isNotEmpty
        ? result.recipient.name.trim()
        : recipientName;
    if (result.recipientHasRestriction) {
      return '$name tiene varios envios al cobro sin pagar. No es posible continuar esta venta al cobro.';
    }
    return '$name registra envios al cobro sin pagar. Puedes continuar al cobro bajo advertencia o cambiar a contado.';
  }

  List<Widget> _actions(BuildContext context) {
    if (result.senderHasDebts || result.recipientHasRestriction) {
      return [
        _ActionButton(
          label: 'Continuar de contado',
          onPressed: () => Navigator.of(
            context,
          ).pop(VenderRestrictiveListAction.continueCash),
        ),
        const SizedBox(height: 10),
        _SecondaryActionButton(
          label: 'Cancelar venta',
          onPressed: () =>
              Navigator.of(context).pop(VenderRestrictiveListAction.cancelSale),
        ),
      ];
    }
    return [
      _ActionButton(
        label: 'Continuar con al cobro',
        onPressed: () => Navigator.of(
          context,
        ).pop(VenderRestrictiveListAction.continueCollect),
      ),
      const SizedBox(height: 10),
      _SecondaryActionButton(
        label: 'Continuar de contado',
        onPressed: () =>
            Navigator.of(context).pop(VenderRestrictiveListAction.continueCash),
      ),
    ];
  }
}

class _DebtList extends StatelessWidget {
  const _DebtList({required this.debts});

  final List<VenderRestrictiveListDebt> debts;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: debts.map((debt) {
          return ListTile(
            dense: true,
            title: Text(
              debt.guideNumber.trim().isEmpty
                  ? 'Guia sin numero'
                  : 'Guia ${debt.guideNumber}',
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              debt.recipient.trim().isEmpty
                  ? debt.restrictionDate
                  : debt.recipient,
              style: const TextStyle(fontFamily: 'Montserrat'),
            ),
            trailing: Text(
              _money(debt.value),
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.black,
        side: const BorderSide(color: AppColors.black),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

String _money(double value) {
  final text = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final reverseIndex = text.length - i;
    buffer.write(text[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write('.');
  }
  return '\$$buffer';
}
