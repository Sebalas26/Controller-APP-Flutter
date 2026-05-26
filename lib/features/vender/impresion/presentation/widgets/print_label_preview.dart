import 'package:flutter/material.dart';

import '../../models/print_label_models.dart';

class PrintLabelPreview extends StatelessWidget {
  const PrintLabelPreview({super.key, required this.label});

  final VenderPrintLabel label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E6EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label.fromReprint ? 'Reimpresion de etiqueta' : 'Etiqueta',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (label.offline)
                  const _Badge(label: 'Offline')
                else
                  const _Badge(label: 'Online'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              label.displayGuide,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _FakeBarcode(value: label.displayGuide),
            const SizedBox(height: 18),
            _Section(
              title: 'Destinatario',
              rows: [
                _RowData('Nombre', label.recipientName),
                _RowData('Documento', label.recipientDocument),
                _RowData('Telefono', label.recipientPhone),
                _RowData('Ciudad', label.recipientCity),
                _RowData('Direccion', label.recipientAddress),
              ],
            ),
            const Divider(height: 28),
            _Section(
              title: 'Remitente',
              rows: [
                _RowData('Nombre', label.senderName),
                _RowData('Documento', label.senderDocument),
                _RowData('Telefono', label.senderPhone),
                _RowData('Ciudad', label.senderCity),
              ],
            ),
            const Divider(height: 28),
            _Section(
              title: 'Detalle',
              rows: [
                _RowData('Servicio', label.serviceName),
                _RowData('Entrega', label.deliveryType),
                _RowData('Piezas', label.pieces),
                _RowData('Peso', label.weight),
                _RowData('Contiene', label.content),
                _RowData('Total', label.totalValue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_RowData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    row.label,
                    style: const TextStyle(
                      color: Color(0xFF696F79),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value.trim().isEmpty ? '-' : row.value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RowData {
  const _RowData(this.label, this.value);

  final String label;
  final String value;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _FakeBarcode extends StatelessWidget {
  const _FakeBarcode({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final bars = digits.isEmpty ? '1234567890' : digits;
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: bars.split('').take(22).map((digit) {
          final width = 1 + ((int.tryParse(digit) ?? 1) % 4);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: ColoredBox(
              color: Colors.black,
              child: SizedBox(width: width.toDouble()),
            ),
          );
        }).toList(),
      ),
    );
  }
}
