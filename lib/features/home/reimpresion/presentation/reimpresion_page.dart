import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/network/controller_api_config.dart';
import '../../../login/login.dart';
import '../../../vender/impresion/impresion.dart';
import '../data/reimpresion_remote_repository.dart';

class ReimpresionPage extends StatefulWidget {
  const ReimpresionPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<ReimpresionPage> createState() => _ReimpresionPageState();
}

class _ReimpresionPageState extends State<ReimpresionPage> {
  final _guideController = TextEditingController();
  final _localRepository = VenderPrintLocalRepository();
  final _remoteRepository = ReimpresionRemoteRepository();
  final _pdfService = PrintLabelPdfService();
  final _deviceService = PrintDeviceService();

  VenderPrintLabel? _label;
  bool _busy = false;
  bool _networkWarning = false;
  String? _message;
  bool _messageIsError = false;
  String? _error;

  @override
  void dispose() {
    _guideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPrint = _guideController.text.trim().isNotEmpty && !_busy;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Atras',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Imprimir',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 120),
        children: [
          TextField(
            controller: _guideController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {
              _label = null;
              _message = null;
              _messageIsError = false;
              _error = null;
              _networkWarning = false;
            }),
            decoration: const InputDecoration(
              labelText: 'Numero de guia',
              suffixText: '*',
            ),
          ),
          if (_networkWarning) ...[
            const SizedBox(height: 20),
            const _WarningBanner(
              message:
                  'En este momento se encuentra sin red para generar la re-impresion',
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            _ResultBanner(message: _message!, error: _messageIsError),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ResultBanner(message: _error!, error: true),
          ],
          if (_label != null) ...[
            const SizedBox(height: 22),
            PrintLabelPreview(label: _label!),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: canPrint ? _reprint : null,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _label == null
                          ? 'Imprimir Etiqueta'
                          : 'Reimprimir Etiqueta',
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reprint() async {
    final guide = _guideController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (guide.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
      _error = null;
      _networkWarning = false;
    });
    try {
      final label = await _findLabel(guide);
      if (label == null) {
        setState(() {
          _networkWarning = true;
          _busy = false;
        });
        return;
      }
      final reprintLabel = VenderPrintLabel.fromJson({
        ...label.toJson(),
        'NumeroGuia': guide,
        'fromReimpresion': true,
      });
      await _localRepository.saveLatestPrintPayload(
        guideNumber: reprintLabel.guideNumber,
        payloadJson: jsonEncode(reprintLabel.toJson()),
      );
      final file = await _pdfService.createLabelPdf(reprintLabel);
      final printed = await _deviceService.printPdfFile(
        file.path,
        jobName: 'Reimpresion ${reprintLabel.displayGuide}',
      );
      final previewMessage = printed
          ? 'Etiqueta enviada a impresion.'
          : Platform.isIOS
          ? 'No fue posible imprimir en la SEWO LK-P25. Verifica que este encendida y enlazada por Bluetooth; puedes revisar la etiqueta aqui.'
          : 'No fue posible imprimir en la SEWO. Puedes revisar la etiqueta aqui.';
      final previewMessageIsError = !printed;
      if (!widget.offline) {
        unawaited(
          _remoteRepository.auditReprint(
            config: widget.apiConfig,
            appInformation: widget.appInformation,
            guideNumber: reprintLabel.guideNumber,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _label = reprintLabel;
        _message = previewMessage;
        _messageIsError = previewMessageIsError;
      });
      await _openPreview(
        reprintLabel,
        file,
        previewMessage,
        isError: previewMessageIsError,
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<VenderPrintLabel?> _findLabel(String guide) async {
    final local = await _localRepository.labelByGuide(guide);
    if (local != null) return local;
    if (widget.offline) return null;
    return _remoteRepository.fetchLabelByGuide(
      config: widget.apiConfig,
      appInformation: widget.appInformation,
      guideNumber: guide,
    );
  }

  Future<void> _openPreview(
    VenderPrintLabel label,
    File file,
    String? message, {
    bool isError = false,
  }) {
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
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFE76100),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
    );
  }
}
