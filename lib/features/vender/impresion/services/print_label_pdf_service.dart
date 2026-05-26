import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/print_label_models.dart';

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
  static const _height = 420.0;
  static const _margin = 12.0;

  final VenderPrintLabel label;

  List<int> build() {
    final content = _content();
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '''
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${_width.toStringAsFixed(0)} ${_height.toStringAsFixed(0)}] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>
''',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
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

    _text(
      content,
      'INTER RAPIDISIMO',
      x: _margin,
      y: 398,
      size: 12,
      bold: true,
    );
    _text(
      content,
      label.fromReprint ? 'REIMPRESION DE ETIQUETA' : 'ETIQUETA',
      x: _margin,
      y: 383,
      size: 9,
      bold: true,
    );
    _rightText(content, label.offline ? 'OFFLINE' : 'ONLINE', y: 383);
    _line(content, 12, 374, 204, 374);

    _text(content, 'GUIA', x: _margin, y: 359, size: 8, bold: true);
    _text(
      content,
      label.displayGuide,
      x: _margin,
      y: 338,
      size: 24,
      bold: true,
    );
    _code39(content, label.displayGuide, x: 14, y: 298, width: 188, height: 28);
    _line(content, 12, 286, 204, 286);

    var y = 270.0;
    y = _section(content, 'DESTINATARIO', y);
    y = _field(content, 'Nombre', label.recipientName, y);
    y = _field(content, 'Documento', label.recipientDocument, y);
    y = _field(content, 'Telefono', label.recipientPhone, y);
    y = _field(content, 'Ciudad', label.recipientCity, y);
    y = _field(content, 'Direccion', label.recipientAddress, y, lines: 2);
    if (label.destinationPostalCode.isNotEmpty) {
      y = _field(content, 'CP', label.destinationPostalCode, y);
    }

    y -= 4;
    y = _section(content, 'REMITENTE', y);
    y = _field(content, 'Nombre', label.senderName, y);
    y = _field(content, 'Documento', label.senderDocument, y);
    y = _field(content, 'Telefono', label.senderPhone, y);
    y = _field(content, 'Ciudad', label.senderCity, y);

    y -= 4;
    y = _section(content, 'DETALLE', y);
    y = _field(content, 'Servicio', label.serviceName, y);
    y = _field(content, 'Entrega', label.deliveryType, y);
    y = _field(
      content,
      'Piezas / Peso',
      '${_dash(label.pieces)} / ${_dash(label.weight)} kg',
      y,
    );
    y = _field(content, 'Contiene', label.content, y, lines: 2);
    y = _field(content, 'Bolsa', label.securityBag, y);

    _line(content, 12, 46, 204, 46);
    _text(content, 'Total', x: _margin, y: 31, size: 8, bold: true);
    _text(
      content,
      _money(label.totalValue),
      x: 70,
      y: 29,
      size: 12,
      bold: true,
    );
    _text(
      content,
      'Fecha: ${_date(label.admissionDate)}',
      x: _margin,
      y: 16,
      size: 7,
    );
    _rightText(content, _date(label.estimatedDeliveryDate), y: 16);

    return content.toString();
  }

  double _section(StringBuffer content, String title, double y) {
    _text(content, title, x: _margin, y: y, size: 8, bold: true);
    _line(content, 12, y - 5, 204, y - 5);
    return y - 16;
  }

  double _field(
    StringBuffer content,
    String label,
    String value,
    double y, {
    int lines = 1,
  }) {
    final text = _wrap(_dash(value), lines == 1 ? 28 : 34).take(lines).toList();
    _text(content, '$label:', x: _margin, y: y, size: 7, bold: true);
    for (var index = 0; index < text.length; index += 1) {
      _text(content, text[index], x: 60, y: y - (index * 10), size: 7);
    }
    return y - (math.max(1, text.length) * 10);
  }

  void _text(
    StringBuffer content,
    String value, {
    required double x,
    required double y,
    required double size,
    bool bold = false,
  }) {
    content.writeln(
      'BT /${bold ? 'F2' : 'F1'} $size Tf $x $y Td (${_pdfText(value)}) Tj ET',
    );
  }

  void _rightText(StringBuffer content, String value, {required double y}) {
    final text = _pdfText(value);
    final x = math.max(_margin, _width - _margin - (text.length * 4.5));
    _text(content, text, x: x.toDouble(), y: y, size: 7, bold: true);
  }

  void _line(StringBuffer content, double x1, double y1, double x2, double y2) {
    content.writeln('$x1 $y1 m $x2 $y2 l S');
  }

  void _code39(
    StringBuffer content,
    String value, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    final encoded = '*${value.replaceAll(RegExp(r'[^0-9A-Z\\-\\. ]'), '')}*';
    final modules = encoded.split('').fold<int>(0, (total, char) {
      final pattern = _code39Patterns[char] ?? _code39Patterns['*']!;
      return total +
          pattern
              .split('')
              .fold<int>(
                0,
                (subtotal, item) => subtotal + (item == 'w' ? 3 : 1),
              ) +
          1;
    });
    final narrow = math.max(0.55, width / modules);
    var cursor = x;
    for (final char in encoded.split('')) {
      final pattern = _code39Patterns[char] ?? _code39Patterns['*']!;
      for (var i = 0; i < pattern.length; i += 1) {
        final elementWidth = narrow * (pattern[i] == 'w' ? 3 : 1);
        if (i.isEven) {
          content.writeln(
            '${cursor.toStringAsFixed(2)} ${y.toStringAsFixed(2)} '
            '${elementWidth.toStringAsFixed(2)} ${height.toStringAsFixed(2)} re f',
          );
        }
        cursor += elementWidth;
      }
      cursor += narrow;
    }
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
      var cut = remaining.lastIndexOf(' ', max);
      if (cut < 8) cut = max;
      yield remaining.substring(0, cut).trim();
      remaining = remaining.substring(cut).trim();
    }
  }

  String _money(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    if (parsed <= 0) return r'$ 0';
    return r'$ ' + parsed.toStringAsFixed(0);
  }

  String _date(String value) {
    if (value.trim().isEmpty) return '-';
    return value.replaceFirst('T', ' ').split('.').first;
  }

  String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();

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
}

const _code39Patterns = <String, String>{
  '0': 'nnnwwnwnn',
  '1': 'wnnwnnnnw',
  '2': 'nnwwnnnnw',
  '3': 'wnwwnnnnn',
  '4': 'nnnwwnnnw',
  '5': 'wnnwwnnnn',
  '6': 'nnwwwnnnn',
  '7': 'nnnwnnwnw',
  '8': 'wnnwnnwnn',
  '9': 'nnwwnnwnn',
  'A': 'wnnnnwnnw',
  'B': 'nnwnnwnnw',
  'C': 'wnwnnwnnn',
  'D': 'nnnnwwnnw',
  'E': 'wnnnwwnnn',
  'F': 'nnwnwwnnn',
  'G': 'nnnnnwwnw',
  'H': 'wnnnnwwnn',
  'I': 'nnwnnwwnn',
  'J': 'nnnnwwwnn',
  'K': 'wnnnnnnww',
  'L': 'nnwnnnnww',
  'M': 'wnwnnnnwn',
  'N': 'nnnnwnnww',
  'O': 'wnnnwnnwn',
  'P': 'nnwnwnnwn',
  'Q': 'nnnnnnwww',
  'R': 'wnnnnnwwn',
  'S': 'nnwnnnwwn',
  'T': 'nnnnwnwwn',
  'U': 'wwnnnnnnw',
  'V': 'nwwnnnnnw',
  'W': 'wwwnnnnnn',
  'X': 'nwnnwnnnw',
  'Y': 'wwnnwnnnn',
  'Z': 'nwwnwnnnn',
  '-': 'nwnnnnwnw',
  '.': 'wwnnnnwnn',
  ' ': 'nwwnnnwnn',
  r'$': 'nwnwnwnnn',
  '/': 'nwnwnnnwn',
  '+': 'nwnnnwnwn',
  '%': 'nnnwnwnwn',
  '*': 'nwnnwnwnn',
};
