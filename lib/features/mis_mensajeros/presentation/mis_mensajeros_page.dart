import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../models/mis_mensajeros_models.dart';
import 'controllers/mis_mensajeros_controller.dart';

const _background = Color(0xFFF3F3F3);
const _border = Color(0xFFE2E2E2);
const _cardGray = Color(0xFFF5F5F5);
const _muted = Color(0xFF6F6F6F);

class MisMensajerosPage extends StatefulWidget {
  const MisMensajerosPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<MisMensajerosPage> createState() => _MisMensajerosPageState();
}

class _MisMensajerosPageState extends State<MisMensajerosPage> {
  late final MisMensajerosController _controller;
  String? _lastShownMessage;

  @override
  void initState() {
    super.initState();
    _controller = MisMensajerosController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
    )..addListener(_handleControllerEvents);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerEvents)
      ..dispose();
    super.dispose();
  }

  void _handleControllerEvents() {
    final message = _controller.errorMessage ?? _controller.statusMessage;
    if (!mounted || message == null || message == _lastShownMessage) return;
    _lastShownMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isError = _controller.errorMessage == message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.red : AppColors.green,
          duration: Duration(seconds: isError ? 5 : 3),
        ),
      );
    });
  }

  Future<void> _openCreateOtpDialog() async {
    final validation = _controller.validateCreateSupport();
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation), backgroundColor: AppColors.red),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateOtpDialog(controller: _controller),
    );
  }

  Future<void> _toggleSupport(MisMensajero support, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Text('¿Estas seguro de inactivar a este mensajero?'),
          content: const Text(
            'Al inhabilitarlo, las guías asignadas se transferirán al ID principal y quedarán disponibles para reasignar a otro apoyo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.black),
              child: const Text('Inactivar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _controller.updateSupportState(support, active);
  }

  Future<void> _callSupport(String phone) async {
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 7) clean = '601$clean';
    if (clean.isEmpty) return;
    final opened = await launchUrl(
      Uri.parse('tel:$clean'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible abrir la llamada.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _whatsappSupport(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    final opened = await launchUrl(
      Uri.parse('https://wa.me/$clean'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu dispositivo no cuenta con la aplicación de WhatsApp. Para enviar el mensaje, descarga la aplicación y completa el registro.',
          ),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: _background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Atras',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
        ),
        title: const Text(
          'Mis mensajeros',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox(
                          height: 50,
                          width: 210,
                          child: FilledButton.icon(
                            onPressed: _openCreateOtpDialog,
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Crear Mensajeros'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.black,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Buscar Mensajero',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      _SearchField(controller: _controller),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Listado',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '(${_controller.filteredSupports.length})',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_controller.filteredSupports.isEmpty)
                        _EmptyState(
                          loading: _controller.loading,
                          offline: widget.offline,
                        )
                      else
                        ..._controller.filteredSupports.map(
                          (support) => _SupportTile(
                            support: support,
                            updating: _controller.updatingState,
                            onToggle: (active) =>
                                _toggleSupport(support, active),
                            onCall: () => _callSupport(support.telefono),
                            onWhatsapp: () =>
                                _whatsappSupport(support.telefono),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_controller.loading ||
                  _controller.sendingOtp ||
                  _controller.updatingState)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final MisMensajerosController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: TextField(
                controller: controller.searchController,
                onChanged: (_) => controller.searchChanged(),
                onSubmitted: (_) => controller.search(),
                decoration: const InputDecoration(
                  hintText: 'Ingresa el nombre',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Buscar',
            onPressed: controller.search,
            icon: const Icon(Icons.search, color: AppColors.black),
          ),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.support,
    required this.updating,
    required this.onToggle,
    required this.onCall,
    required this.onWhatsapp,
  });

  final MisMensajero support;
  final bool updating;
  final ValueChanged<bool> onToggle;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _cardGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(12, 8, 8, 2),
            childrenPadding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
            title: Text(
              support.nombre,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Tel: ${support.telefono}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(
                    height: 14,
                    child: VerticalDivider(width: 1, color: _muted),
                  ),
                  Text(
                    support.loginUsuario,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            trailing: Switch(
              value: support.usuarioActivo,
              onChanged: updating ? null : onToggle,
              activeThumbColor: AppColors.black,
              activeTrackColor: AppColors.gray500,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: IconButton.filledTonal(
                      tooltip: 'Llamar',
                      onPressed: onCall,
                      icon: const Icon(Icons.call_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.gray200,
                        foregroundColor: AppColors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IconButton.filledTonal(
                      tooltip: 'WhatsApp',
                      onPressed: onWhatsapp,
                      icon: const Icon(Icons.chat_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.gray200,
                        foregroundColor: AppColors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateOtpDialog extends StatefulWidget {
  const _CreateOtpDialog({required this.controller});

  final MisMensajerosController controller;

  @override
  State<_CreateOtpDialog> createState() => _CreateOtpDialogState();
}

class _CreateOtpDialogState extends State<_CreateOtpDialog> {
  Future<void> _sendOtp() async {
    final success = await widget.controller.generateOtpCode();
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Cerrar',
                      onPressed: widget.controller.sendingOtp
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ),
                  const Text(
                    'Crear Código',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      child: Text(
                        'Ingresa el número de celular de tu mensajero. Recibira un SMS con un código OTP',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Número de celular mensajero'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: widget.controller.otpPhoneController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Ingrese número celular de su apoyo',
                              filled: true,
                              fillColor: AppColors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: widget.controller.sendingOtp ? null : _sendOtp,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.black,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: widget.controller.sendingOtp
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Enviar'),
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loading, required this.offline});

  final bool loading;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              loading ? Icons.hourglass_empty : Icons.group_outlined,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              loading ? 'Consultando apoyos...' : 'Sin mensajeros',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              offline
                  ? 'No hay apoyos guardados localmente para mostrar.'
                  : 'No se encontraron apoyos con los filtros actuales.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}
