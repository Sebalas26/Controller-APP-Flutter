import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/print_label_models.dart';
import '../utils/code128_barcode.dart';

class PrintLabelPdfService {
  Future<File> createLabelPdf(VenderPrintLabel label) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'controller_labels'));
    if (!await directory.exists()) await directory.create(recursive: true);
    final file = File(
      path.join(directory.path, 'etiqueta_${label.displayGuide}.pdf'),
    );
    final bytes = _PdfLabelDocument(label).build();
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

class _PdfLabelDocument {
  _PdfLabelDocument(this.label);

  static const _width = 216.0;
  static const _margin = 2.0;

  final VenderPrintLabel label;

  double get _height => label.offline ? 740.0 : 700.0;

  List<int> build() {
    final content = _content();
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '''
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${_width.toStringAsFixed(0)} ${_height.toStringAsFixed(0)}] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>
''',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Courier-Bold >>',
      '<< /Length ${latin1.encode(content).length} >>\nstream\n$content\nendstream',
    ];

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (var index = 0; index < objects.length; index += 1) {
      offsets.add(latin1.encode(buffer.toString()).length);
      buffer
        ..write('${index + 1} 0 obj\n')
        ..write(objects[index].trim())
        ..write('\nendobj\n');
    }
    final xrefOffset = latin1.encode(buffer.toString()).length;
    buffer
      ..write('xref\n')
      ..write('0 ${objects.length + 1}\n')
      ..write('0000000000 65535 f \n');
    for (var index = 1; index < offsets.length; index += 1) {
      buffer
        ..write(offsets[index].toString().padLeft(10, '0'))
        ..write(' 00000 n \n');
    }
    buffer
      ..write('trailer\n')
      ..write('<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
      ..write('startxref\n')
      ..write('$xrefOffset\n')
      ..write('%%EOF\n');
    return latin1.encode(buffer.toString());
  }

  String _content() {
    final content = StringBuffer()
      ..writeln('1 1 1 rg')
      ..writeln('0 0 $_width $_height re f')
      ..writeln('0 0 0 rg')
      ..writeln('0.7 w');

    var top = 15.0;
    _inlineTop(
      content,
      'FECHA ESTIMADA DE ENTREGA: ',
      _date(label.estimatedDeliveryDate),
      x: _margin,
      y: top,
      size: 8,
    );
    _serviceMark(content, x: 178, y: 20);

    top += 18;
    _textTop(
      content,
      _dash(label.serviceName),
      x: _margin,
      y: top,
      size: 14,
      bold: true,
    );
    top += 17;
    _textTop(
      content,
      _dash(label.timeWindow),
      x: _margin,
      y: top,
      size: 14,
      bold: true,
    );
    top += 17;
    _inlineTop(
      content,
      'FECHA ADMISION: ',
      _dateTime(label.admissionDate),
      x: _margin,
      y: top,
      size: 8,
    );
    top += 12;

    if (label.hasRetirementWindow) {
      _inlineTop(
        content,
        'FECHA PARA RETIRAR: ',
        _dateOnly(label.estimatedDeliveryDate),
        x: _margin,
        y: top,
        size: 8,
      );
      top += 9;
      _inlineTop(
        content,
        'HASTA: ',
        _dateOnly(label.estimatedDeliveryDateNew),
        x: _margin,
        y: top,
        size: 8,
      );
      top += 11;
    }

    _routeTable(content, top);
    top += 83;

    _textTop(content, 'GUIA:', x: _margin, y: top, size: 13);
    _textTop(content, label.displayGuide, x: 40, y: top, size: 13, bold: true);
    if (label.zoneLabel.isNotEmpty) {
      _rightTextTop(
        content,
        label.zoneLabel,
        right: 211,
        y: top,
        size: 13,
        bold: true,
      );
    }
    top += 12;

    _code128(
      content,
      label.displayGuide,
      x: _margin,
      yTop: top,
      width: 212,
      height: 50,
    );
    top += 65;

    top = _addressBox(
      content,
      top: top,
      height: 72,
      sideLabel: 'DE:',
      lines: [
        _PdfLine(label.senderName, bold: true, size: 8.6, maxChars: 26),
        _PdfLine(
          'CC: ${_dash(label.senderDocument)} | TEL: ${_dash(label.senderPhone)}',
          size: 7.4,
          maxChars: 34,
        ),
        _PdfLine(label.senderAddress, size: 7.4, maxChars: 36, maxLines: 2),
        _PdfLine(label.senderCity, bold: true, size: 8, maxChars: 33),
        _PdfLine(
          'COD. POSTAL: ${_firstFilled([label.senderPostalCode, label.senderCity])}',
          size: 7.3,
          maxChars: 34,
        ),
      ],
    );
    top += 4;
    top = _addressBox(
      content,
      top: top,
      height: 98,
      sideLabel: 'PARA:',
      lines: [
        _PdfLine(label.recipientName, bold: true, size: 8.8, maxChars: 25),
        _PdfLine(
          'CC: ${_dash(label.recipientDocument)} | TEL: ${_dash(label.recipientPhone)}',
          size: 7.4,
          maxChars: 34,
        ),
        _PdfLine(
          label.recipientAddress,
          bold: true,
          size: 8.5,
          maxChars: 30,
          maxLines: 2,
        ),
        _PdfLine(label.recipientCity, bold: true, size: 8, maxChars: 33),
        _PdfLine(
          'COD.POSTAL:${_dash(label.destinationPostalCode)}',
          size: 7.4,
          maxChars: 34,
        ),
        if (!label.offline)
          _PdfLine(
            'BOLSA:${_dash(label.securityBag)}',
            size: 7.4,
            maxChars: 34,
          ),
        _PdfLine(
          'OBS: ${_dash(label.observation)}',
          size: 7.3,
          maxChars: 34,
          maxLines: 2,
        ),
      ],
    );

    if (label.offline) {
      top += 11;
      _textTop(content, _dash(label.deliveryType), x: _margin, y: top, size: 9);
      top += 12;
      _inlineTop(
        content,
        'VALOR COMERCIAL:',
        '\$${label.commercialDisplayValue}',
        x: _margin,
        y: top,
        size: 9,
        boldValue: true,
      );
      top += 12;
      _inlineTop(
        content,
        'CONTIENE:',
        _dash(label.content),
        x: _margin,
        y: top,
        size: 9,
        boldValue: true,
      );
      top += 16;
    } else {
      top += 12;
    }

    _inlineTop(
      content,
      'PESO: ',
      '${_weight(label.weight)}KG',
      x: _margin,
      y: top,
      size: 11,
      boldValue: true,
    );
    _inlineTop(
      content,
      'COD VTA: ',
      _dash(label.saleCenterCode),
      x: 125,
      y: top,
      size: 11,
      boldValue: true,
    );
    top += 14;

    _geoGrid(content, top);
    top += 101;

    if (_amount(label.cashOnDeliveryValue) > 0) {
      _arrow(content, x: 176, y: top - 10);
      top += 10;
    }

    _qr(content, x: _margin, y: top, size: 80);
    _textTop(content, 'Valor a cobrar:', x: 111, y: top + 26, size: 11);
    if (_amount(label.cashOnDeliveryValue) > 0) {
      _rightTextTop(content, 'PEC', right: 211, y: top + 50, size: 10);
    }
    _rightTextTop(
      content,
      '\$${label.chargeValue}',
      right: 211,
      y: top + 66,
      size: 20,
      bold: true,
    );
    _rightTextTop(
      content,
      _dash(label.paymentMethod),
      right: 211,
      y: top + 88,
      size: 11,
    );
    top += 105;

    _centerTextTop(
      content,
      'www.interrapidisimo.com',
      center: 108,
      y: top,
      size: 10,
    );
    top += 12;
    if (label.offline) {
      _centerTextTop(content, 'offline', center: 108, y: top, size: 10);
      top += 12;
    }
    if (label.fromReprint) {
      _centerTextTop(content, 'Reimpresion', center: 108, y: top, size: 7);
      _watermark(content, centerY: _height / 2);
    }

    return content.toString();
  }

  double _addressBox(
    StringBuffer content, {
    required double top,
    required double height,
    required String sideLabel,
    required List<_PdfLine> lines,
  }) {
    _rectTop(content, _margin, top, 212, height);
    _lineTop(content, 22, top, 22, top + height);
    _rotatedTextTop(
      content,
      sideLabel,
      x: 9,
      y: top + (height / 2) + 10,
      size: 10,
      bold: true,
    );

    var lineTop = top + 12;
    for (final line in lines) {
      if (line.value.trim().isEmpty) continue;
      final wrapped = _wrap(line.value, line.maxChars).take(line.maxLines);
      for (final text in wrapped) {
        if (lineTop > top + height - 4) break;
        _textTop(
          content,
          text,
          x: 27,
          y: lineTop,
          size: line.size,
          bold: line.bold,
        );
        lineTop += line.size + 2.2;
      }
    }
    return top + height;
  }

  void _routeTable(StringBuffer content, double top) {
    const widths = [53.0, 38.0, 30.0, 30.0, 30.0, 30.0];
    final xs = <double>[_margin];
    for (var index = 1; index < widths.length; index += 1) {
      xs.add(xs[index - 1] + widths[index - 1]);
    }
    final stops = List<VenderPrintRouteStop>.generate(5, (index) {
      if (index < label.routeStops.length) return label.routeStops[index];
      return const VenderPrintRouteStop(shortCity: '', locker: '', door: '');
    });

    _lineTop(content, xs[1], top + 10, xs[1], top + 60);
    _lineTop(content, 214, top + 10, 214, top + 60);
    _textTop(content, 'RUTA', x: xs[0] + 5, y: top + 20, size: 9, bold: true);
    _textTop(
      content,
      'CASILLA',
      x: xs[0] + 5,
      y: top + 40,
      size: 9,
      bold: true,
    );
    _textTop(content, 'PUERTA', x: xs[0] + 5, y: top + 60, size: 9, bold: true);

    for (var index = 0; index < stops.length; index += 1) {
      final col = index + 1;
      final start = xs[col];
      final center = start + (widths[col] / 2);
      _centerTextTop(
        content,
        stops[index].shortCity,
        center: center,
        y: top + 20,
        size: 12,
        bold: true,
      );
      _centerTextTop(
        content,
        stops[index].locker,
        center: center,
        y: top + 38,
        size: 12,
        bold: true,
      );
      _lineTop(content, start + 4, top + 42, start + widths[col] - 4, top + 42);
      _centerTextTop(
        content,
        stops[index].door,
        center: center,
        y: top + 58,
        size: 12,
        bold: true,
      );
    }
  }

  void _geoGrid(StringBuffer content, double top) {
    final headers = label.hasRetirementWindow
        ? const ['NODO', 'ZO.PAMI', 'RO']
        : const ['NODO', 'ZO.PAMI', 'MANZANA'];
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
    const cellWidth = 70.0;
    const rowHeights = [15.0, 30.0, 15.0, 30.0];
    var rowTop = top;
    _rectTop(content, _margin, top, cellWidth * 3, 90);
    for (var row = 0; row < rows.length; row += 1) {
      final height = rowHeights[row];
      for (var col = 0; col < 3; col += 1) {
        final left = _margin + (col * cellWidth);
        _lineTop(content, left, rowTop, left, rowTop + height);
        _centerTextTop(
          content,
          _dash(rows[row][col]),
          center: left + (cellWidth / 2),
          y: rowTop + (height / 2) + (row.isEven ? 3 : 5),
          size: row.isEven ? 9 : 13,
          bold: true,
        );
      }
      rowTop += height;
      _lineTop(content, _margin, rowTop, _margin + (cellWidth * 3), rowTop);
    }
  }

  void _serviceMark(
    StringBuffer content, {
    required double x,
    required double y,
  }) {
    _rectTop(content, x, y, 34, 34);
    _centerTextTop(
      content,
      _initials(label.serviceName),
      center: x + 17,
      y: y + 22,
      size: 12,
      bold: true,
    );
  }

  void _arrow(StringBuffer content, {required double x, required double y}) {
    _lineTop(content, x, y + 10, x + 22, y + 10);
    _lineTop(content, x + 22, y + 10, x + 14, y + 4);
    _lineTop(content, x + 22, y + 10, x + 14, y + 16);
    _rectTop(content, x - 2, y - 2, 30, 24);
  }

  void _qr(
    StringBuffer content, {
    required double x,
    required double y,
    required double size,
  }) {
    _rectTop(content, x, y, size, size);
    const modules = 25;
    final cell = size / modules;
    final seed = label.displayGuide.codeUnits.fold<int>(
      17,
      (hash, code) => hash * 31 + code,
    );
    _qrFinder(content, x, y, cell, 1, 1);
    _qrFinder(content, x, y, cell, 17, 1);
    _qrFinder(content, x, y, cell, 1, 17);
    for (var row = 0; row < modules; row += 1) {
      for (var col = 0; col < modules; col += 1) {
        if (_insideQrFinder(col, row)) continue;
        final mixed = seed + col * 13 + row * 29 + col * row;
        if (mixed % 5 == 0 || mixed % 7 == 0) {
          _rectTop(
            content,
            x + (col * cell),
            y + (row * cell),
            cell,
            cell,
            fill: true,
          );
        }
      }
    }
  }

  void _qrFinder(
    StringBuffer content,
    double x,
    double y,
    double cell,
    int col,
    int row,
  ) {
    _rectTop(
      content,
      x + col * cell,
      y + row * cell,
      cell * 7,
      cell * 7,
      fill: true,
    );
    _rectTop(
      content,
      x + (col + 1) * cell,
      y + (row + 1) * cell,
      cell * 5,
      cell * 5,
      fillWhite: true,
    );
    _rectTop(
      content,
      x + (col + 2) * cell,
      y + (row + 2) * cell,
      cell * 3,
      cell * 3,
      fill: true,
    );
  }

  bool _insideQrFinder(int x, int y) {
    return (x >= 1 && x < 8 && y >= 1 && y < 8) ||
        (x >= 17 && x < 24 && y >= 1 && y < 8) ||
        (x >= 1 && x < 8 && y >= 17 && y < 24);
  }

  void _code128(
    StringBuffer content,
    String value, {
    required double x,
    required double yTop,
    required double width,
    required double height,
  }) {
    final barcode = Code128Barcode.fromValue(value);
    final moduleWidth = width / barcode.totalModules;
    for (final bar in barcode.bars) {
      _rectTop(
        content,
        x + (bar.startModule * moduleWidth),
        yTop,
        bar.moduleCount * moduleWidth,
        height,
        fill: true,
      );
    }
  }

  void _inlineTop(
    StringBuffer content,
    String labelText,
    String value, {
    required double x,
    required double y,
    required double size,
    bool boldValue = false,
  }) {
    _textTop(content, labelText, x: x, y: y, size: size);
    _textTop(
      content,
      value,
      x: x + _measure(labelText, size),
      y: y,
      size: size,
      bold: boldValue,
    );
  }

  void _textTop(
    StringBuffer content,
    String value, {
    required double x,
    required double y,
    required double size,
    bool bold = false,
  }) {
    final pdfY = _height - y;
    content.writeln(
      'BT /${bold ? 'F2' : 'F1'} ${_n(size)} Tf ${_n(x)} ${_n(pdfY)} Td (${_pdfText(value)}) Tj ET',
    );
  }

  void _rotatedTextTop(
    StringBuffer content,
    String value, {
    required double x,
    required double y,
    required double size,
    bool bold = false,
  }) {
    final pdfY = _height - y;
    content.writeln(
      'BT /${bold ? 'F2' : 'F1'} ${_n(size)} Tf 0 -1 1 0 ${_n(x)} ${_n(pdfY)} Tm (${_pdfText(value)}) Tj ET',
    );
  }

  void _rightTextTop(
    StringBuffer content,
    String value, {
    required double right,
    required double y,
    required double size,
    bool bold = false,
  }) {
    final x = right - _measure(value, size);
    _textTop(
      content,
      value,
      x: math.max(_margin, x),
      y: y,
      size: size,
      bold: bold,
    );
  }

  void _centerTextTop(
    StringBuffer content,
    String value, {
    required double center,
    required double y,
    required double size,
    bool bold = false,
  }) {
    final x = center - (_measure(value, size) / 2);
    _textTop(
      content,
      value,
      x: math.max(_margin, x),
      y: y,
      size: size,
      bold: bold,
    );
  }

  void _lineTop(
    StringBuffer content,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    content.writeln(
      '${_n(x1)} ${_n(_height - y1)} m ${_n(x2)} ${_n(_height - y2)} l S',
    );
  }

  void _rectTop(
    StringBuffer content,
    double x,
    double y,
    double width,
    double height, {
    bool fill = false,
    bool fillWhite = false,
  }) {
    final pdfY = _height - y - height;
    if (fillWhite) {
      content
        ..writeln('1 1 1 rg')
        ..writeln('${_n(x)} ${_n(pdfY)} ${_n(width)} ${_n(height)} re f')
        ..writeln('0 0 0 rg');
      return;
    }
    content.writeln(
      '${_n(x)} ${_n(pdfY)} ${_n(width)} ${_n(height)} re ${fill ? 'f' : 'S'}',
    );
  }

  void _watermark(StringBuffer content, {required double centerY}) {
    final radians = -55 * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    content.writeln(
      'BT /F2 42 Tf ${_n(cos)} ${_n(sin)} ${_n(-sin)} ${_n(cos)} 40 ${_n(centerY)} Tm (RE IMPRESION) Tj ET',
    );
  }

  Iterable<String> _wrap(String value, int max) sync* {
    final clean = _sanitize(value);
    if (clean.length <= max) {
      yield clean;
      return;
    }
    var remaining = clean;
    while (remaining.isNotEmpty) {
      if (remaining.length <= max) {
        yield remaining;
        return;
      }
      var split = remaining.lastIndexOf(' ', max);
      if (split < 8) split = max;
      yield remaining.substring(0, split).trim();
      remaining = remaining.substring(split).trim();
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

  String _initials(String value) {
    final parts = _sanitize(value)
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .take(2)
        .map((item) => item.substring(0, 1).toUpperCase())
        .join();
    return parts.isEmpty ? 'IR' : parts;
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

  double _measure(String value, double size) {
    return _sanitize(value).length * size * 0.58;
  }

  String _pdfText(String value) {
    return _sanitize(
      value,
    ).replaceAll('\\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
  }

  String _sanitize(String value) {
    const replacements = {
      '\u00e1': 'a',
      '\u00e9': 'e',
      '\u00ed': 'i',
      '\u00f3': 'o',
      '\u00fa': 'u',
      '\u00c1': 'A',
      '\u00c9': 'E',
      '\u00cd': 'I',
      '\u00d3': 'O',
      '\u00da': 'U',
      '\u00f1': 'n',
      '\u00d1': 'N',
    };
    final replaced = value.runes.map((code) {
      final char = String.fromCharCode(code);
      return replacements[char] ?? char;
    }).join();
    return replaced.runes
        .where((code) => code >= 32 && code <= 126)
        .map(String.fromCharCode)
        .join()
        .trim();
  }

  String _n(num value) {
    return value.toStringAsFixed(2);
  }
}

class _PdfLine {
  const _PdfLine(
    this.value, {
    required this.size,
    required this.maxChars,
    this.bold = false,
    this.maxLines = 1,
  });

  final String value;
  final double size;
  final int maxChars;
  final bool bold;
  final int maxLines;
}
