import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../models/tarjeta_comercial_models.dart';
import 'controllers/tarjeta_comercial_controller.dart';

const _surface = Color(0xFFFEFEFE);
const _pageBackground = Color(0xFFF5F5F5);
const _border = Color(0xFFE0E0E0);
const _muted = Color(0xFF727272);
const _blue = Color(0xFF2569B3);
const _softBlue = Color(0xFFE8EFF7);
const _whatsappGreen = Color(0xFF01623D);

class TarjetaComercialPage extends StatefulWidget {
  const TarjetaComercialPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<TarjetaComercialPage> createState() => _TarjetaComercialPageState();
}

class _TarjetaComercialPageState extends State<TarjetaComercialPage> {
  late final TarjetaComercialController _controller;
  final _phoneFocusNode = FocusNode();
  String? _lastShownMessage;

  @override
  void initState() {
    super.initState();
    _controller = TarjetaComercialController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
    )..addListener(_handleControllerMessages);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _phoneFocusNode.dispose();
    _controller
      ..removeListener(_handleControllerMessages)
      ..dispose();
    super.dispose();
  }

  void _clearPhoneAndFocus() {
    _controller.clearPhone();
    _phoneFocusNode.requestFocus();
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
          backgroundColor: isError ? AppColors.red : _whatsappGreen,
          duration: Duration(seconds: isError ? 5 : 4),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBackground,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              Column(
                children: [
                  _TarjetaHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _TarjetaContent(
                            controller: _controller,
                            phoneFocusNode: _phoneFocusNode,
                            onClearPhone: _clearPhoneAndFocus,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_controller.loading || _controller.sending)
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

class _TarjetaHeader extends StatelessWidget {
  const _TarjetaHeader({required this.onBack});

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
            icon: const Icon(Icons.close, color: AppColors.black),
            tooltip: 'Cerrar',
          ),
          const Expanded(
            child: Text(
              'Tarjeta comercial',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _blue,
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _TarjetaContent extends StatelessWidget {
  const _TarjetaContent({
    required this.controller,
    required this.phoneFocusNode,
    required this.onClearPhone,
  });

  final TarjetaComercialController controller;
  final FocusNode phoneFocusNode;
  final VoidCallback onClearPhone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CourierHeader(controller: controller),
            const SizedBox(height: 22),
            const Text(
              'Enviar a WhatsApp',
              style: TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _PhoneAndSend(
              controller: controller,
              phoneFocusNode: phoneFocusNode,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: controller.sending ? null : onClearPhone,
                child: const Text('+ Enviar a otro número celular'),
              ),
            ),
            const Divider(height: 28, color: _border),
            _ConsentRow(
              value: controller.consentCommercial,
              onChanged: controller.sending
                  ? null
                  : controller.toggleCommercialConsent,
              text:
                  'He informado al titular del dato que será usado para contactarlo con fines comerciales y/o publicitarios de Inter Rapidísimo S.A.',
            ),
            const SizedBox(height: 10),
            _DataConsentRow(
              value: controller.consentData,
              onChanged: controller.sending
                  ? null
                  : controller.toggleDataConsent,
            ),
            const SizedBox(height: 20),
            _InfoList(items: controller.items, loading: controller.loading),
          ],
        ),
      ),
    );
  }
}

class _CourierHeader extends StatelessWidget {
  const _CourierHeader({required this.controller});

  final TarjetaComercialController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _softBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.person_outline, color: _blue, size: 42),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.appInformation.displayName.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Punto de atención móvil',
                style: TextStyle(
                  color: _muted,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhoneAndSend extends StatelessWidget {
  const _PhoneAndSend({required this.controller, required this.phoneFocusNode});

  final TarjetaComercialController controller;
  final FocusNode phoneFocusNode;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhoneField(controller: controller, focusNode: phoneFocusNode),
          const SizedBox(height: 10),
          _SendButton(controller: controller),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _PhoneField(controller: controller, focusNode: phoneFocusNode),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 118, child: _SendButton(controller: controller)),
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.focusNode});

  final TarjetaComercialController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.phoneController,
      focusNode: focusNode,
      enabled: !controller.sending,
      keyboardType: TextInputType.phone,
      onChanged: (_) => controller.phoneChanged(),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Celular',
        prefixIcon: const Icon(Icons.chat_outlined),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.3),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.controller});

  final TarjetaComercialController controller;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: controller.canSend ? controller.sendWhatsapp : null,
      icon: controller.sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_outlined, size: 18),
      label: const Text('Envíar'),
      style: FilledButton.styleFrom(
        backgroundColor: _whatsappGreen,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.gray300,
        disabledForegroundColor: AppColors.gray700,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.text,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Checkbox(
                value: value,
                onChanged: onChanged == null
                    ? null
                    : (newValue) => onChanged!(newValue ?? false),
                activeColor: _whatsappGreen,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    height: 1.35,
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

class _DataConsentRow extends StatelessWidget {
  const _DataConsentRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Checkbox(
                value: value,
                onChanged: onChanged == null
                    ? null
                    : (newValue) => onChanged!(newValue ?? false),
                activeColor: _whatsappGreen,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      color: AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'El titular al suministrar su número autoriza el tratamiento de datos personales para la finalidades indicadas en la pagina web ',
                      ),
                      TextSpan(
                        text:
                            'https://interrapidisimo.com/proteccion-de-datos-personales/',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
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

class _InfoList extends StatelessWidget {
  const _InfoList({required this.items, required this.loading});

  final List<TarjetaComercialItem> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparte tu tarjeta comercial a tus clientes para que puedan acceder a:',
              style: TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (items.where((item) => item.hasDescription).isEmpty)
              const Text(
                'No hay información local de tarjeta comercial.',
                style: TextStyle(
                  color: _muted,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  height: 1.35,
                ),
              )
            else
              ...items
                  .where((item) => item.hasDescription)
                  .map((item) => _InfoBullet(text: item.description)),
          ],
        ),
      ),
    );
  }
}

class _InfoBullet extends StatelessWidget {
  const _InfoBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '- ',
            style: TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 14,
              height: 1.35,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
