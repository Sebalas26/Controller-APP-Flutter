import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/vender_print_local_repository.dart';
import '../models/print_label_models.dart';
import '../services/print_device_service.dart';
import '../services/print_label_pdf_service.dart';
import 'print_label_preview_page.dart';
import 'widgets/print_label_preview.dart';

class VenderPrintPage extends StatefulWidget {
  const VenderPrintPage({
    super.key,
    required this.guideNumber,
    this.initialLabel,
    this.title = 'Imprimir etiqueta',
  });

  final String guideNumber;
  final VenderPrintLabel? initialLabel;
  final String title;

  @override
  State<VenderPrintPage> createState() => _VenderPrintPageState();
}

class _VenderPrintPageState extends State<VenderPrintPage> {
  final _localRepository = VenderPrintLocalRepository();
  final _pdfService = PrintLabelPdfService();
  final _deviceService = PrintDeviceService();

  VenderPrintLabel? _label;
  bool _loading = true;
  bool _printing = false;
  String? _message;
  bool _messageIsError = false;
  String? _error;
  File? _lastPdf;

  @override
  void initState() {
    super.initState();
    _label = widget.initialLabel;
    unawaited(_loadLabel());
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : label == null
          ? const _PrintEmpty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                if (_message != null)
                  _Banner(message: _message!, error: _messageIsError),
                if (_error != null) _Banner(message: _error!, error: true),
                PrintLabelPreview(label: label),
              ],
            ),
      bottomNavigationBar: label == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _printing ? null : _generatePdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Generar PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _printing ? null : _printBluetoothOrPdf,
                        icon: const Icon(Icons.print_outlined),
                        label: Text(_printing ? 'Procesando' : 'Imprimir'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _loadLabel() async {
    try {
      final loaded =
          _label ?? await _localRepository.labelByGuide(widget.guideNumber);
      if (!mounted) return;
      setState(() {
        _label = loaded;
        _loading = false;
        _error = loaded == null
            ? 'No se encontro informacion local para imprimir la guia.'
            : null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<File?> _createPdf() async {
    final label = _label;
    if (label == null) return null;
    final file = await _pdfService.createLabelPdf(label);
    _lastPdf = file;
    return file;
  }

  Future<void> _generatePdf() async {
    await _runPrinting(() async {
      final file = await _createPdf();
      if (file == null) return;
      _message = 'PDF generado correctamente.';
      _messageIsError = false;
      if (mounted) {
        await _openPreview(file, 'PDF generado correctamente.');
      }
    });
  }

  Future<void> _printBluetoothOrPdf() async {
    await _runPrinting(() async {
      final file = await _createPdf();
      if (file == null) return;
      final printed = await _deviceService.printPdfFile(
        file.path,
        jobName: 'Etiqueta ${_label!.displayGuide}',
      );
      _message = printed
          ? 'Etiqueta enviada a impresion.'
          : Platform.isIOS
          ? 'No fue posible imprimir en la SEWO LK-P25. Verifica que este encendida y enlazada por Bluetooth; puedes revisar la etiqueta aqui.'
          : 'No fue posible imprimir en la SEWO. Puedes revisar la etiqueta aqui.';
      _messageIsError = !printed;
      if (mounted) {
        await _openPreview(file, _message, isError: !printed);
      }
    });
  }

  Future<void> _openPreview(
    File file,
    String? message, {
    bool isError = false,
  }) {
    final label = _label;
    if (label == null) return Future<void>.value();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrintLabelPreviewPage(
          label: label,
          pdfFile: file,
          initialMessage: message,
          initialMessageIsError: isError,
        ),
      ),
    );
  }

  Future<void> _runPrinting(Future<void> Function() action) async {
    setState(() {
      _printing = true;
      _error = null;
      _message = null;
      _messageIsError = false;
    });
    try {
      await action();
    } on Object catch (error) {
      _error = error.toString();
      final file = _lastPdf;
      if (file != null && mounted) {
        await _openPreview(
          file,
          'No fue posible imprimir. Puedes revisar la etiqueta aqui.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

class _PrintEmpty extends StatelessWidget {
  const _PrintEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print_disabled_outlined, size: 56),
            SizedBox(height: 12),
            Text(
              'No hay etiqueta para imprimir',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              'Genera una admision o consulta una guia desde Reimpresion.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF696F79)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: error ? const Color(0xFFFFECEC) : const Color(0xFFE7F5EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: error ? const Color(0xFFCF1111) : const Color(0xFF01623D),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: TextStyle(
              color: error ? const Color(0xFFCF1111) : const Color(0xFF01623D),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
