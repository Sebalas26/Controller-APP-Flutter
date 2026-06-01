import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/native/controller_native_bridge.dart';
import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../models/multientrega_models.dart';
import 'controllers/multientrega_controller.dart';

const _surface = Color(0xFFFEFEFE);
const _border = Color(0xFFE0E0E0);
const _muted = Color(0xFF727272);
const _success = Color(0xFF01623D);

enum _MultientregaStep { list, signature }

class MultientregaPage extends StatefulWidget {
  const MultientregaPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<MultientregaPage> createState() => _MultientregaPageState();
}

class _MultientregaPageState extends State<MultientregaPage> {
  late final MultientregaController _controller;
  final _nativeBridge = ControllerNativeBridge();
  _MultientregaStep _step = _MultientregaStep.list;
  String? _lastShownMessage;

  @override
  void initState() {
    super.initState();
    _controller = MultientregaController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
    )..addListener(_handleControllerMessages);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerMessages)
      ..dispose();
    super.dispose();
  }

  void _handleControllerMessages() {
    final message = _controller.errorMessage ?? _controller.statusMessage;
    if (!mounted || message == null || message == _lastShownMessage) return;
    _lastShownMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isError = _controller.errorMessage == message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.red : _success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<void> _leave() async {
    if (_step == _MultientregaStep.signature) {
      setState(() => _step = _MultientregaStep.list);
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              children: [
                _NativeHeader(
                  title: _step == _MultientregaStep.list
                      ? 'Multi-Entrega'
                      : 'Entregar',
                  onBack: _leave,
                ),
                if (_controller.loading || _controller.saving)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: _step == _MultientregaStep.list
                      ? _MultientregaListStep(
                          controller: _controller,
                          nativeBridge: _nativeBridge,
                          onContinue: () {
                            if (!_controller.canGoToSignature) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Agrega mínimo dos guías y toma la foto de cada envío.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            setState(() => _step = _MultientregaStep.signature);
                          },
                        )
                      : _FirmaSelloStep(
                          controller: _controller,
                          nativeBridge: _nativeBridge,
                          onSaved: () {
                            setState(() => _step = _MultientregaStep.list);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NativeHeader extends StatelessWidget {
  const _NativeHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.black),
            tooltip: 'Atras',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultientregaListStep extends StatelessWidget {
  const _MultientregaListStep({
    required this.controller,
    required this.nativeBridge,
    required this.onContinue,
  });

  final MultientregaController controller;
  final ControllerNativeBridge nativeBridge;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 18),
            children: [
              _ModeSwitch(count: controller.guides.length),
              const SizedBox(height: 20),
              _GuideSearch(controller: controller, nativeBridge: nativeBridge),
              const SizedBox(height: 15),
              if (controller.guides.isEmpty)
                const _EmptyMultientrega()
              else
                ...controller.guides.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _MultientregaGuideCard(
                      item: item,
                      nativeBridge: nativeBridge,
                      onPhoto: (photo) =>
                          controller.updatePhoto(item.guideNumber, photo),
                      onDelete: () => _confirmDelete(context, item.guideNumber),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (controller.guides.length > 1)
          TextButton.icon(
            onPressed: controller.saving
                ? null
                : () => _confirmClear(context, controller),
            icon: const Icon(Icons.close, color: AppColors.black, size: 18),
            label: const Text(
              'Eliminar listado',
              style: TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: controller.canGoToSignature ? onContinue : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.gray200,
                disabledForegroundColor: AppColors.gray500,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Firma y sello',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, String guideNumber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar guía'),
        content: const Text('¿Está seguro de eliminar esta guía?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (confirm == true) await controller.deleteGuide(guideNumber);
  }

  Future<void> _confirmClear(
    BuildContext context,
    MultientregaController controller,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar listado'),
        content: Text(
          '¿Está seguro de eliminar?\n(${controller.guides.length}) guías',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (confirm == true) await controller.clearGuides();
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text(
                'Individual',
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Múltiple $count',
                style: const TextStyle(
                  color: AppColors.white,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSearch extends StatelessWidget {
  const _GuideSearch({required this.controller, required this.nativeBridge});

  final MultientregaController controller;
  final ControllerNativeBridge nativeBridge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray500),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: controller.canAddGuide
                ? () => _runAdd(context, controller.guideController.text)
                : null,
            icon: const Icon(Icons.search, color: AppColors.black),
            tooltip: 'Buscar guía',
          ),
          Expanded(
            child: TextField(
              controller: controller.guideController,
              enabled: controller.canAddGuide,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(14),
              ],
              onSubmitted: (value) => _runAdd(context, value),
              decoration: const InputDecoration(
                hintText: 'Agregue varios envíos',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.black),
              onPressed: controller.canAddGuide
                  ? () async {
                      final guide = await nativeBridge.scanQrCode();
                      if (!context.mounted) return;
                      if (guide.trim().isNotEmpty) {
                        await _runAdd(context, guide);
                      }
                    }
                  : null,
              icon: const Icon(Icons.qr_code_scanner, color: AppColors.white),
              tooltip: 'Escanear',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runAdd(BuildContext context, String value) async {
    try {
      await controller.addGuide(value);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _EmptyMultientrega extends StatelessWidget {
  const _EmptyMultientrega();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 44),
      child: Column(
        children: const [
          Icon(Icons.inventory_2_outlined, color: AppColors.gray500, size: 56),
          SizedBox(height: 12),
          Text(
            'Sin guías en multientrega',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MultientregaGuideCard extends StatelessWidget {
  const _MultientregaGuideCard({
    required this.item,
    required this.nativeBridge,
    required this.onPhoto,
    required this.onDelete,
  });

  final MultientregaGuide item;
  final ControllerNativeBridge nativeBridge;
  final ValueChanged<String> onPhoto;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.black),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.guideNumber,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.guide.serviceName.trim().isEmpty
                      ? 'Mensajería'
                      : item.guide.serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                    children: [
                      const TextSpan(text: 'Valor a cobrar: '),
                      TextSpan(
                        text: _money(item.valueToCollect),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 96, color: AppColors.gray500),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: () => _takePhoto(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: item.hasPhoto
                          ? _success
                          : AppColors.black,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.hasPhoto ? 'Foto' : 'Foto'),
                        const SizedBox(width: 4),
                        Icon(
                          item.hasPhoto
                              ? Icons.check_circle_outline
                              : Icons.photo_camera_outlined,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.black,
                  ),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _takePhoto(BuildContext context) async {
    final photo = await nativeBridge.takePackagePhoto();
    final jpeg = await ensureJpegImage(
      nativeBridge,
      photo,
      maxDimension: 480,
      quality: 35,
      maxBase64Length: 45 * 1024,
    );
    if (jpeg.trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible capturar la foto.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    onPhoto(jpeg);
  }
}

class _FirmaSelloStep extends StatefulWidget {
  const _FirmaSelloStep({
    required this.controller,
    required this.nativeBridge,
    required this.onSaved,
  });

  final MultientregaController controller;
  final ControllerNativeBridge nativeBridge;
  final VoidCallback onSaved;

  @override
  State<_FirmaSelloStep> createState() => _FirmaSelloStepState();
}

class _FirmaSelloStepState extends State<_FirmaSelloStep> {
  final _signatureKey = GlobalKey<_SignaturePadState>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
            children: [
              Center(
                child: SizedBox(
                  width: 260,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Re imprimir Etiqueta',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _UnderlineInput(
                controller: widget.controller.receiverController,
                hint: 'Quien recibe (Nombre y Apellido)',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                  LengthLimitingTextInputFormatter(50),
                ],
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 30),
              _UnderlineInput(
                controller: widget.controller.documentController,
                hint: 'Número de documento',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(50),
                ],
              ),
              const SizedBox(height: 30),
              _UnderlineInput(
                controller: widget.controller.observationsController,
                hint: 'Observaciones',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                  LengthLimitingTextInputFormatter(150),
                ],
                textCapitalization: TextCapitalization.characters,
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              _SealSwitch(controller: widget.controller),
              const SizedBox(height: 20),
              const _SignatureWarning(),
              const SizedBox(height: 20),
              const Text(
                'Firma recibido',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _SignaturePad(key: _signatureKey),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _captureSignature,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.black,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  widget.controller.signatureBase64.trim().isEmpty
                      ? 'Registrar firma del cliente'
                      : 'Firma registrada',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              const Text(
                'Total a cobrar:',
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                _money(widget.controller.totalToCollect),
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: widget.controller.sealEnabled
                        ? _takeSealPhoto
                        : null,
                    icon: Icon(
                      widget.controller.sealBase64.trim().isEmpty
                          ? Icons.photo_camera_outlined
                          : Icons.check_circle_outline,
                    ),
                    label: const Text('Sello'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          widget.controller.sealBase64.trim().isEmpty
                          ? AppColors.black
                          : _success,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.gray200,
                      disabledForegroundColor: AppColors.gray500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: widget.controller.canSave ? _save : null,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      widget.controller.saving ? 'Guardando' : 'Guardar',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.gray200,
                      disabledForegroundColor: AppColors.gray500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _captureSignature() async {
    final signatureCapture = await _signatureKey.currentState?.capture() ?? '';
    final signature = await ensureJpegImage(
      widget.nativeBridge,
      signatureCapture,
      maxDimension: 420,
      quality: 35,
      maxBase64Length: 10 * 1024,
    );
    if (signatureCapture.trim().isNotEmpty && signature.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible convertir la firma a JPEG.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.controller.setSignature(signature);
  }

  Future<void> _takeSealPhoto() async {
    final photo = await widget.nativeBridge.takePackagePhoto();
    final jpeg = await ensureJpegImage(
      widget.nativeBridge,
      photo,
      maxDimension: 480,
      quality: 35,
      maxBase64Length: 45 * 1024,
    );
    if (jpeg.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible tomar la foto del sello.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.controller.setSeal(jpeg);
  }

  Future<void> _save() async {
    try {
      await widget.controller.saveMultientrega();
      if (mounted) widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _UnderlineInput extends StatelessWidget {
  const _UnderlineInput({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: const Text(
          '*',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 24),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.black, width: 2),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.black, width: 2),
        ),
      ),
      style: const TextStyle(
        color: AppColors.black,
        fontFamily: 'Montserrat',
        fontSize: 15,
      ),
    );
  }
}

class _SealSwitch extends StatelessWidget {
  const _SealSwitch({required this.controller});

  final MultientregaController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Registra entrega con sello',
            style: TextStyle(
              color: AppColors.accent,
              fontFamily: 'Montserrat',
              fontSize: 16,
            ),
          ),
        ),
        Switch(
          value: controller.sealEnabled,
          onChanged: controller.requiresSeal ? null : controller.setSealEnabled,
          activeThumbColor: AppColors.black,
        ),
      ],
    );
  }
}

class _SignatureWarning extends StatelessWidget {
  const _SignatureWarning();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.black),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Es muy importante que se solicite la firma al cliente y que sea válida para el registro de la prueba de entrega.',
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePad extends StatefulWidget {
  const _SignaturePad({super.key});

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  final _points = <Offset?>[];
  Size _lastSize = const Size(320, 170);

  bool get hasSignature => _points.whereType<Offset>().length > 1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastSize = Size(constraints.maxWidth, 180);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.black),
            borderRadius: BorderRadius.circular(5),
          ),
          child: SizedBox(
            height: _lastSize.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _addPoint(details.localPosition),
                      onPanUpdate: (details) =>
                          _addPoint(details.localPosition),
                      onPanEnd: (_) => _endStroke(),
                      child: CustomPaint(
                        painter: _SignaturePainter(_points),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 54,
                    bottom: 6,
                    child: IconButton.filledTonal(
                      onPressed: _maximize,
                      tooltip: 'Maximizar firma',
                      icon: const Icon(Icons.open_in_full),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: IconButton.filledTonal(
                      onPressed: _clear,
                      tooltip: 'Limpiar',
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> capture() async {
    if (!hasSignature) return '';
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & _lastSize;
    canvas.drawRect(rect, Paint()..color = Colors.white);
    canvas.clipRect(rect);
    _SignaturePainter(_points).paint(canvas, _lastSize);
    final image = await recorder.endRecording().toImage(
      _lastSize.width.round().clamp(1, 2000).toInt(),
      _lastSize.height.round().clamp(1, 2000).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return '';
    return base64Encode(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }

  Future<void> _maximize() async {
    final result = await Navigator.of(context).push<List<Offset?>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _SignatureFullscreenPage(points: _points),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _points
        ..clear()
        ..addAll(result);
    });
  }

  void _addPoint(Offset offset) {
    final width = _lastSize.width;
    final height = _lastSize.height;
    if (width <= 0 || height <= 0) return;
    final isInside =
        offset.dx >= 0 &&
        offset.dy >= 0 &&
        offset.dx <= width &&
        offset.dy <= height;
    if (!isInside) {
      _endStroke();
      return;
    }
    setState(() => _points.add(Offset(offset.dx / width, offset.dy / height)));
  }

  void _endStroke() {
    if (_points.isEmpty || _points.last == null) return;
    setState(() => _points.add(null));
  }

  void _clear() {
    setState(_points.clear);
  }
}

class _SignatureFullscreenPage extends StatefulWidget {
  const _SignatureFullscreenPage({required this.points});

  final List<Offset?> points;

  @override
  State<_SignatureFullscreenPage> createState() =>
      _SignatureFullscreenPageState();
}

class _SignatureFullscreenPageState extends State<_SignatureFullscreenPage> {
  late final List<Offset?> _points = List<Offset?>.from(widget.points);
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]),
    );
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Firma recibido'),
        actions: [
          TextButton(
            onPressed: _accept,
            child: const Text('Aceptar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              const _SignatureWarning(),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.black),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _lastSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (details) =>
                                    _addPoint(details.localPosition),
                                onPanUpdate: (details) =>
                                    _addPoint(details.localPosition),
                                onPanEnd: (_) => _endStroke(),
                                child: CustomPaint(
                                  painter: _SignaturePainter(_points),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: IconButton.filledTonal(
                                onPressed: _clear,
                                tooltip: 'Limpiar',
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _accept,
                  icon: const Icon(Icons.check),
                  label: const Text('Aceptar firma'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addPoint(Offset offset) {
    final width = _lastSize.width;
    final height = _lastSize.height;
    if (width <= 0 || height <= 0) return;
    final isInside =
        offset.dx >= 0 &&
        offset.dy >= 0 &&
        offset.dx <= width &&
        offset.dy <= height;
    if (!isInside) {
      _endStroke();
      return;
    }
    setState(() => _points.add(Offset(offset.dx / width, offset.dy / height)));
  }

  void _endStroke() {
    if (_points.isEmpty || _points.last == null) return;
    setState(() => _points.add(null));
  }

  void _clear() {
    setState(_points.clear);
  }

  void _accept() {
    Navigator.of(context).pop(List<Offset?>.from(_points));
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      if (current == null || next == null) continue;
      canvas.drawLine(
        Offset(current.dx * size.width, current.dy * size.height),
        Offset(next.dx * size.width, next.dy * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) {
    return true;
  }
}

Future<String> ensureJpegImage(
  ControllerNativeBridge nativeBridge,
  String imageBase64, {
  required int maxDimension,
  required int quality,
  required int maxBase64Length,
}) async {
  final cleanImage = cleanBase64(imageBase64);
  if (cleanImage.isEmpty) return '';
  final converted = await nativeBridge.compressImageBase64ToJpeg(
    cleanImage,
    maxDimension: maxDimension,
    quality: quality,
    maxBase64Length: maxBase64Length,
  );
  final cleanConverted = cleanBase64(converted);
  if (isJpegBase64(cleanConverted) &&
      cleanConverted.length <= maxBase64Length) {
    return cleanConverted;
  }
  if (isJpegBase64(cleanImage) && cleanImage.length <= maxBase64Length) {
    return cleanImage;
  }
  return '';
}

bool isJpegBase64(String imageBase64) {
  try {
    final bytes = base64Decode(cleanBase64(imageBase64));
    return bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  } on Object {
    return false;
  }
}

String cleanBase64(String value) {
  return value
      .split('base64,')
      .last
      .replaceAll('\n', '')
      .replaceAll('\r', '')
      .trim();
}

String _money(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    final reverseIndex = text.length - index;
    buffer.write(text[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write('.');
  }
  return '\$ ${buffer.toString()}';
}
