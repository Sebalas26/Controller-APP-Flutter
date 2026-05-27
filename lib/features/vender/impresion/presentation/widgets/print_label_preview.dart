import 'package:flutter/material.dart';

import '../../models/print_label_models.dart';
import '../../utils/code128_barcode.dart';

class PrintLabelPreview extends StatelessWidget {
  const PrintLabelPreview({super.key, required this.label});

  final VenderPrintLabel label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.05,
                    letterSpacing: 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InlineText(
                        label: 'FECHA ESTIMADA DE ENTREGA: ',
                        value: _date(label.estimatedDeliveryDate),
                        size: 10,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StrongLine(
                                  _dash(label.serviceName),
                                  size: 19,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 5),
                                _StrongLine(
                                  _dash(label.timeWindow),
                                  size: 17,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _ServiceMark(label: label),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _InlineText(
                        label: 'FECHA ADMISION: ',
                        value: _dateTime(label.admissionDate),
                        size: 10,
                      ),
                      if (label.hasRetirementWindow) ...[
                        const SizedBox(height: 3),
                        _InlineText(
                          label: 'FECHA PARA RETIRAR: ',
                          value: _dateOnly(label.estimatedDeliveryDate),
                          size: 10,
                        ),
                        const SizedBox(height: 2),
                        _InlineText(
                          label: 'HASTA: ',
                          value: _dateOnly(label.estimatedDeliveryDateNew),
                          size: 10,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _RouteGrid(stops: label.routeStops),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'GUIA:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              label.displayGuide,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (label.zoneLabel.isNotEmpty)
                            Text(
                              label.zoneLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 62,
                        child: CustomPaint(
                          painter: _BarcodePainter(label.displayGuide),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AddressBox(
                        sideLabel: 'DE:',
                        lines: [
                          _AddressLine(label.senderName, bold: true),
                          _AddressLine(
                            'CC: ${_dash(label.senderDocument)} | TEL: ${_dash(label.senderPhone)}',
                          ),
                          _AddressLine(label.senderAddress),
                          _AddressLine(label.senderCity, bold: true),
                          _AddressLine(
                            'COD. POSTAL: ${_firstFilled([label.senderPostalCode, label.senderCity])}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _AddressBox(
                        sideLabel: 'PARA:',
                        lines: [
                          _AddressLine(label.recipientName, bold: true),
                          _AddressLine(
                            'CC: ${_dash(label.recipientDocument)} | TEL: ${_dash(label.recipientPhone)}',
                          ),
                          _AddressLine(
                            label.recipientAddress,
                            bold: true,
                            maxLines: 2,
                          ),
                          _AddressLine(label.recipientCity, bold: true),
                          _AddressLine(
                            'COD.POSTAL:${_dash(label.destinationPostalCode)}',
                          ),
                          if (!label.offline)
                            _AddressLine('BOLSA:${_dash(label.securityBag)}'),
                          _AddressLine('OBS: ${_dash(label.observation)}'),
                        ],
                      ),
                      if (label.offline) ...[
                        const SizedBox(height: 8),
                        _StrongLine(_dash(label.deliveryType), size: 12),
                        const SizedBox(height: 4),
                        _InlineText(
                          label: 'VALOR COMERCIAL:',
                          value: '\$${label.commercialDisplayValue}',
                          size: 12,
                          boldValue: true,
                        ),
                        const SizedBox(height: 4),
                        _InlineText(
                          label: 'CONTIENE:',
                          value: _dash(label.content),
                          size: 12,
                          boldValue: true,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _InlineText(
                            label: 'PESO: ',
                            value: '${_weight(label.weight)}KG',
                            size: 14,
                            boldValue: true,
                          ),
                          const Spacer(),
                          _InlineText(
                            label: 'COD VTA: ',
                            value: _dash(label.saleCenterCode),
                            size: 14,
                            boldValue: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _GeoGrid(
                        label: label,
                        headers: label.hasRetirementWindow
                            ? const ['NODO', 'ZO.PAMI', 'RO']
                            : const ['NODO', 'ZO.PAMI', 'MANZANA'],
                      ),
                      const SizedBox(height: 12),
                      if (_amount(label.cashOnDeliveryValue) > 0)
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Icon(Icons.subdirectory_arrow_right, size: 28),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox.square(
                            dimension: 94,
                            child: CustomPaint(
                              painter: _QrPainter(label.displayGuide),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const SizedBox(height: 20),
                                const Text(
                                  'Valor a cobrar:',
                                  style: TextStyle(fontSize: 13),
                                ),
                                if (_amount(label.cashOnDeliveryValue) > 0)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: Text(
                                      'PEC',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '\$${label.chargeValue}',
                                      style: const TextStyle(
                                        fontSize: 27,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _dash(label.paymentMethod),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'www.interrapidisimo.com',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      if (label.offline)
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Center(
                            child: Text(
                              'offline',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      if (label.fromReprint)
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Center(
                            child: Text(
                              'Reimpresion',
                              style: TextStyle(fontSize: 9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (label.fromReprint)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.95,
                      child: Text(
                        'RE IMPRESION',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.15),
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceMark extends StatelessWidget {
  const _ServiceMark({required this.label});

  final VenderPrintLabel label;

  @override
  Widget build(BuildContext context) {
    final initials = label.serviceName
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .take(2)
        .map((item) => item.characters.first.toUpperCase())
        .join();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: Text(
            initials.isEmpty ? 'IR' : initials,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _RouteGrid extends StatelessWidget {
  const _RouteGrid({required this.stops});

  final List<VenderPrintRouteStop> stops;

  @override
  Widget build(BuildContext context) {
    final visible = [
      ...stops.take(5),
      ...List<VenderPrintRouteStop>.filled(
        (5 - stops.length).clamp(0, 5).toInt(),
        const VenderPrintRouteStop(shortCity: '', locker: '', door: ''),
      ),
    ];
    return SizedBox(
      height: 70,
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _RouteLabel('RUTA'),
                _RouteLabel('CASILLA'),
                _RouteLabel('PUERTA'),
              ],
            ),
          ),
          Container(width: 1, color: Colors.black),
          ...visible.map(
            (stop) => Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 0.7),
                  ),
                ),
                child: Column(
                  children: [
                    _RouteValue(stop.shortCity),
                    _RouteValue(stop.locker, divider: true),
                    _RouteValue(stop.door),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLabel extends StatelessWidget {
  const _RouteLabel(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _RouteValue extends StatelessWidget {
  const _RouteValue(this.value, {this.divider = false});

  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: divider
              ? const Border(
                  bottom: BorderSide(color: Colors.black, width: 0.7),
                )
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.trim(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressBox extends StatelessWidget {
  const _AddressBox({required this.sideLabel, required this.lines});

  final String sideLabel;
  final List<_AddressLine> lines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    sideLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            Container(width: 1, color: Colors.black),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: lines
                      .where((line) => line.value.trim().isNotEmpty)
                      .map(
                        (line) => Text(
                          line.value,
                          maxLines: line.maxLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: line.bold ? 12 : 10,
                            fontWeight: line.bold
                                ? FontWeight.w900
                                : FontWeight.w500,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressLine {
  const _AddressLine(this.value, {this.bold = false, this.maxLines = 1});

  final String value;
  final bool bold;
  final int maxLines;
}

class _GeoGrid extends StatelessWidget {
  const _GeoGrid({required this.label, required this.headers});

  final VenderPrintLabel label;
  final List<String> headers;

  @override
  Widget build(BuildContext context) {
    final rows = [
      headers,
      [label.geoGrid.node, label.geoGrid.zone, label.geoGrid.block],
      const ['SAT.DIA', 'SAT.24H', 'SAT.NODO'],
      [
        label.geoGrid.satelliteDay,
        label.geoGrid.satellite24h,
        label.geoGrid.satelliteNode,
      ],
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          children: rows.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final row = entry.value;
            final isHeader = rowIndex.isEven;
            return SizedBox(
              height: isHeader ? 22 : 32,
              child: Row(
                children: row.map((value) {
                  return Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.black, width: 0.6),
                          bottom: BorderSide(color: Colors.black, width: 0.6),
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _dash(value),
                            style: TextStyle(
                              fontSize: isHeader ? 11 : 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _InlineText extends StatelessWidget {
  const _InlineText({
    required this.label,
    required this.value,
    required this.size,
    this.boldValue = false,
  });

  final String label;
  final String value;
  final double size;
  final bool boldValue;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: size),
        children: [
          TextSpan(text: label),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: boldValue ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StrongLine extends StatelessWidget {
  const _StrongLine(this.value, {required this.size, this.maxLines = 2});

  final String value;
  final double size;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w900),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.value);

  final String value;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final barcode = Code128Barcode.fromValue(value);
    final moduleWidth = size.width / barcode.totalModules;
    for (final bar in barcode.bars) {
      canvas.drawRect(
        Rect.fromLTWH(
          bar.startModule * moduleWidth,
          0,
          bar.moduleCount * moduleWidth,
          size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.value);

  final String value;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final border = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, border);
    const modules = 25;
    final cell = size.width / modules;
    final seed = value.codeUnits.fold<int>(
      17,
      (hash, code) => hash * 31 + code,
    );
    _finder(canvas, paint, cell, 1, 1);
    _finder(canvas, paint, cell, 17, 1);
    _finder(canvas, paint, cell, 1, 17);
    for (var y = 0; y < modules; y += 1) {
      for (var x = 0; x < modules; x += 1) {
        if (_insideFinder(x, y)) continue;
        final mixed = seed + x * 13 + y * 29 + x * y;
        if (mixed % 5 == 0 || mixed % 7 == 0) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
  }

  void _finder(Canvas canvas, Paint paint, double cell, int x, int y) {
    canvas.drawRect(
      Rect.fromLTWH(x * cell, y * cell, cell * 7, cell * 7),
      paint,
    );
    final white = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH((x + 1) * cell, (y + 1) * cell, cell * 5, cell * 5),
      white,
    );
    canvas.drawRect(
      Rect.fromLTWH((x + 2) * cell, (y + 2) * cell, cell * 3, cell * 3),
      paint,
    );
  }

  bool _insideFinder(int x, int y) {
    return (x >= 1 && x < 8 && y >= 1 && y < 8) ||
        (x >= 17 && x < 24 && y >= 1 && y < 8) ||
        (x >= 1 && x < 8 && y >= 17 && y < 24);
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

String _date(String value) {
  if (value.trim().isEmpty) return '-';
  return value.replaceFirst('T', ' ').split('.').first;
}

String _dateTime(String value) {
  if (value.trim().isEmpty) return '-';
  final clean = value.replaceFirst('T', ' ').split('.').first.trim();
  return clean.replaceFirst(RegExp(r'\s+'), ' - ');
}

String _dateOnly(String value) {
  if (value.trim().isEmpty) return '-';
  return value.replaceFirst('T', ' ').split(' ').first;
}

String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();

String _weight(String value) {
  final parsed = double.tryParse(value.replaceAll(',', '.'));
  if (parsed == null) return _dash(value);
  if (parsed % 1 == 0) return parsed.toStringAsFixed(0);
  return parsed.toString();
}

String _firstFilled(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '-';
}

double _amount(String value) {
  final clean = value.replaceAll(r'$', '').replaceAll(' ', '').trim();
  if (clean.isEmpty) return 0;
  final commaIndex = clean.lastIndexOf(',');
  final dotIndex = clean.lastIndexOf('.');
  var normalized = clean;
  if (commaIndex >= 0 && dotIndex >= 0) {
    normalized = commaIndex > dotIndex
        ? clean.replaceAll('.', '').replaceAll(',', '.')
        : clean.replaceAll(',', '');
  } else if (commaIndex >= 0) {
    final decimals = clean.length - commaIndex - 1;
    normalized = decimals == 3
        ? clean.replaceAll(',', '')
        : clean.replaceAll(',', '.');
  } else if (dotIndex >= 0) {
    final decimals = clean.length - dotIndex - 1;
    normalized = decimals == 3 ? clean.replaceAll('.', '') : clean;
  }
  normalized = normalized.replaceAll(RegExp(r'[^0-9\.-]'), '');
  return double.tryParse(normalized) ?? 0;
}
