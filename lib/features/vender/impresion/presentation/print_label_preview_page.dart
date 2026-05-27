import 'dart:io';

import 'package:flutter/material.dart';

import '../models/print_label_models.dart';
import '../services/print_device_service.dart';
import 'widgets/print_label_preview.dart';

class PrintLabelPreviewPage extends StatefulWidget {
  const PrintLabelPreviewPage({
    super.key,
    required this.label,
    required this.pdfFile,
    this.initialMessage,
    this.initialMessageIsError = false,
  });

  final VenderPrintLabel label;
  final File pdfFile;
  final String? initialMessage;
  final bool initialMessageIsError;

  @override
  State<PrintLabelPreviewPage> createState() => _PrintLabelPreviewPageState();
}

class _PrintLabelPreviewPageState extends State<PrintLabelPreviewPage> {
  final _deviceService = PrintDeviceService();

  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage ?? 'Etiqueta lista para previsualizar.';
    _messageIsError = widget.initialMessageIsError;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Vista previa')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          if (_message != null)
            _Banner(message: _message!, error: _messageIsError),
          if (_error != null) _Banner(message: _error!, error: true),
          PrintLabelPreview(label: widget.label),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _openPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Abrir PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _print,
                  icon: const Icon(Icons.print_outlined),
                  label: Text(_busy ? 'Procesando' : 'Imprimir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPdf() async {
    await _run(() async {
      final opened = await _deviceService.openPdfFile(widget.pdfFile.path);
      _message = opened
          ? 'PDF abierto correctamente.'
          : 'La etiqueta sigue disponible en la vista previa de la app.';
      _messageIsError = !opened;
    });
  }

  Future<void> _print() async {
    await _run(() async {
      final printed = await _deviceService.printPdfFile(
        widget.pdfFile.path,
        jobName: 'Etiqueta ${widget.label.displayGuide}',
      );
      _message = printed
          ? 'Etiqueta enviada a impresion.'
          : Platform.isIOS
          ? 'No fue posible imprimir en la SEWO LK-P25. Verifica que este encendida y enlazada por Bluetooth; puedes abrir el PDF.'
          : 'No fue posible imprimir en la SEWO. Puedes revisar la etiqueta aqui o abrir el PDF.';
      _messageIsError = !printed;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _messageIsError = false;
    });
    try {
      await action();
    } on Object catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
