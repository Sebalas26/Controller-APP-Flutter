import 'package:flutter/material.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import 'controllers/vender_flow_controller.dart';
import 'views/vender_admission_success_view.dart';
import 'views/vender_billing_summary_view.dart';
import 'views/vender_initial_view.dart';
import 'views/vender_person_view.dart';
import 'views/vender_payment_view.dart';
import 'views/vender_settlement_view.dart';
import 'views/vender_summary_view.dart';
import 'widgets/vender_form_widgets.dart';

class VenderPage extends StatefulWidget {
  const VenderPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<VenderPage> createState() => _VenderPageState();
}

class _VenderPageState extends State<VenderPage> {
  late final VenderFlowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VenderFlowController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
    )..addListener(_onControllerChanged);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) {
      return _VenderNativeScaffold(
        title: _titleForStep(),
        onBack: _goBack,
        body: const Center(child: CircularProgressIndicator()),
        footer: const SizedBox.shrink(),
      );
    }

    if (!_controller.hasCatalogs) {
      return _VenderNativeScaffold(
        title: _titleForStep(),
        onBack: _goBack,
        body: VenderEmptyState(
          icon: Icons.storage_outlined,
          title: 'Vender sin catalogos',
          message:
              _controller.errorMessage ??
              'Ejecuta la sincronizacion inicial para cargar datos locales.',
        ),
        footer: const SizedBox.shrink(),
      );
    }

    return _VenderNativeScaffold(
      title: _titleForStep(),
      onBack: _goBack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VenderStatusBanner(
            message: _controller.statusMessage,
            error: _controller.errorMessage,
            loading: _controller.busyRemote || _controller.saving,
          ),
          _bodyForStep(),
        ],
      ),
      footer: _footer(),
    );
  }

  void _goBack() {
    if (_controller.currentStep == 0 || _controller.currentStep >= 5) {
      Navigator.of(context).maybePop();
      return;
    }
    _controller.previousStep();
  }

  String _titleForStep() {
    switch (_controller.currentStep) {
      case 0:
        return 'Datos Envio';
      case 1:
        return 'Confirmar Liquidacion';
      case 2:
        return 'Datos Remitente';
      case 3:
        return 'Datos Destinatario';
      case 4:
        return 'Resumen Admision';
      case 5:
        return 'Envio Admitido';
      case 6:
        return 'Facturar';
      default:
        return 'Cobrar';
    }
  }

  Widget _bodyForStep() {
    switch (_controller.currentStep) {
      case 0:
        return VenderInitialView(
          controller: _controller,
          runAction: _runAction,
        );
      case 1:
        return VenderSettlementView(
          controller: _controller,
          runAction: _runAction,
        );
      case 2:
        return VenderPersonView(
          controller: _controller,
          kind: VenderPersonKind.sender,
          runAction: _runAction,
        );
      case 3:
        return VenderPersonView(
          controller: _controller,
          kind: VenderPersonKind.recipient,
          runAction: _runAction,
        );
      case 4:
        return VenderSummaryView(
          controller: _controller,
          runAction: _runAction,
        );
      case 5:
        return VenderAdmissionSuccessView(
          controller: _controller,
          runAction: _runAction,
        );
      case 6:
        return VenderBillingSummaryView(controller: _controller);
      default:
        return VenderPaymentView(controller: _controller);
    }
  }

  Widget _footer() {
    final showBack = _controller.currentStep > 0 && _controller.currentStep < 5;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.16),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              if (showBack) ...[
                Expanded(
                  child: _NativeFooterButton(
                    label: 'Atras',
                    onPressed: _controller.saving
                        ? null
                        : _controller.previousStep,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: _NativeFooterButton(
                  label: _footerLabel(),
                  icon: _footerIcon(),
                  onPressed: _controller.saving
                      ? null
                      : () => _runAction(_controller.nextStep),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _footerLabel() {
    if (_controller.currentStep == 4) return 'Guardar admision';
    if (_controller.currentStep == 5) return 'No agregar mas envios';
    if (_controller.currentStep == 6) return 'Facturar';
    if (_controller.currentStep == 7) {
      if (_controller.collectionState?.confirmed == true) return 'Nueva venta';
      return _controller.collectionState?.actionLabel ?? 'Confirmar cobro';
    }
    return 'Siguiente';
  }

  IconData _footerIcon() {
    if (_controller.currentStep == 4) return Icons.save_outlined;
    if (_controller.currentStep == 5) return Icons.receipt_long_outlined;
    if (_controller.currentStep == 6) return Icons.receipt_long;
    if (_controller.currentStep == 7) {
      return _controller.collectionState?.confirmed == true
          ? Icons.add
          : Icons.payments_outlined;
    }
    return Icons.arrow_forward;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
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

class _VenderNativeScaffold extends StatefulWidget {
  const _VenderNativeScaffold({
    required this.title,
    required this.onBack,
    required this.body,
    required this.footer,
  });

  final String title;
  final VoidCallback onBack;
  final Widget body;
  final Widget footer;

  @override
  State<_VenderNativeScaffold> createState() => _VenderNativeScaffoldState();
}

class _VenderNativeScaffoldState extends State<_VenderNativeScaffold> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollDown() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.black,
      child: Column(
        children: [
          _VenderNativeToolbar(
            title: widget.title,
            onBack: widget.onBack,
            onScrollDown: _scrollDown,
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.white,
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: widget.body,
              ),
            ),
          ),
          widget.footer,
        ],
      ),
    );
  }
}

class _VenderNativeToolbar extends StatelessWidget {
  const _VenderNativeToolbar({
    required this.title,
    required this.onBack,
    required this.onScrollDown,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onScrollDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.black,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            tooltip: 'Atras',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: onScrollDown,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.white),
            tooltip: 'Bajar',
          ),
        ],
      ),
    );
  }
}

class _NativeFooterButton extends StatelessWidget {
  const _NativeFooterButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.gray200,
        disabledForegroundColor: AppColors.gray500,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        textStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: Icon(icon ?? Icons.chevron_right),
      label: Text(label, textAlign: TextAlign.center),
    );
  }
}
