import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/native/controller_native_bridge.dart';
import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../../multientrega/multientrega.dart';
import '../../pagos/pagos.dart';
import '../models/entregas_models.dart';
import 'controllers/entregas_controller.dart';

enum _EntregaModule { enZona, entregadas, devolucion, buscar }

class EntregasPage extends StatefulWidget {
  const EntregasPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<EntregasPage> createState() => _EntregasPageState();
}

class _EntregasPageState extends State<EntregasPage> {
  late final EntregasController _controller;
  final _nativeBridge = ControllerNativeBridge();
  final _searchController = TextEditingController();
  _EntregaModule _selectedModule = _EntregaModule.buscar;
  bool _lastSearchWasQr = false;

  @override
  void initState() {
    super.initState();
    _controller = EntregasController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
      imageCompressor: _nativeBridge.compressImageBase64ToJpeg,
    )..addListener(_onControllerChanged);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    return ColoredBox(
      color: AppColors.white,
      child: Column(
        children: [
          _EntregasNativeHeader(
            title: _titleFor(_selectedModule),
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _controller.loading
                      ? const _NativeLoadingList()
                      : _body(),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 8,
                  child: _EntregasBanner(controller: _controller),
                ),
              ],
            ),
          ),
          const _TopShadow(),
          _moduleSelector(),
        ],
      ),
    );
  }

  Widget _moduleSelector() {
    return _EntregasBottomTabs(
      selected: _selectedModule,
      inZoneCount: _controller.inZone.length,
      deliveredCount: _controller.delivered.length,
      returnedCount: _controller.returned.length,
      loading: _controller.loading,
      onSelected: (value) {
        setState(() => _selectedModule = value);
        switch (value) {
          case _EntregaModule.enZona:
            _controller.selectStatus(EntregaGuideStatus.enZona);
            break;
          case _EntregaModule.entregadas:
            _controller.selectStatus(EntregaGuideStatus.entregada);
            break;
          case _EntregaModule.devolucion:
            _controller.selectStatus(EntregaGuideStatus.devolucion);
            break;
          case _EntregaModule.buscar:
            break;
        }
      },
    );
  }

  String _titleFor(_EntregaModule module) {
    switch (module) {
      case _EntregaModule.buscar:
        return 'Entregar';
      case _EntregaModule.enZona:
        return 'En Zona';
      case _EntregaModule.entregadas:
        return 'Entregas';
      case _EntregaModule.devolucion:
        return 'Devolucion';
    }
  }

  Widget _body() {
    switch (_selectedModule) {
      case _EntregaModule.enZona:
        return _moduleBody(
          title: 'Guias en zona',
          guides: _controller.inZone,
          emptyIcon: Icons.location_off_outlined,
          onRefresh: _controller.refreshInZone,
          showZoneActions: true,
        );
      case _EntregaModule.entregadas:
        return _moduleBody(
          title: 'Guias entregadas',
          guides: _controller.delivered,
          emptyIcon: Icons.fact_check_outlined,
          onRefresh: _controller.refreshDelivered,
        );
      case _EntregaModule.devolucion:
        return _moduleBody(
          title: 'Guias devueltas',
          guides: _controller.returned,
          emptyIcon: Icons.assignment_return_outlined,
          onRefresh: _controller.refreshReturned,
        );
      case _EntregaModule.buscar:
        return _searchPanel();
    }
  }

  Widget _moduleBody({
    required String title,
    required List<EntregaGuide> guides,
    required IconData emptyIcon,
    required Future<void> Function() onRefresh,
    Widget? trailing,
    bool showZoneActions = false,
  }) {
    final topPadding = showZoneActions ? 62.0 : 16.0;
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, topPadding, 0, 92),
            children: [
              if (trailing != null) ...[trailing, const SizedBox(height: 12)],
              if (guides.isEmpty)
                _EntregasEmptyState(
                  icon: emptyIcon,
                  title: 'Sin guias',
                  message: 'No hay registros para este modulo.',
                )
              else
                ...guides.map((guide) => _guideCard(guide)),
            ],
          ),
        ),
        if (showZoneActions) ...[
          Positioned(
            right: 15,
            top: 10,
            child: _FilterButton(onTap: onRefresh),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: _ZoneActionDock(
              syncing: _controller.syncing,
              onSync: () => _run(_controller.syncPending),
              onRefresh: onRefresh,
              onScan: _openQrDialog,
            ),
          ),
        ] else
          Positioned(
            right: 15,
            top: 10,
            child: _RefreshChip(onPressed: onRefresh),
          ),
      ],
    );
  }

  Widget _searchPanel() {
    final searched = _controller.searchedGuide;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 92),
          children: [
            _DeliveryModeSwitch(onMultiple: _openMultientrega),
            const SizedBox(height: 20),
            _NativeSearchField(
              controller: _searchController,
              onQr: _openQrDialog,
              onSearch: () => _runSearch(_searchController.text),
            ),
            const SizedBox(height: 18),
            const _NativeInfoLegend(
              text:
                  'Escanea el codigo de barras o ingresa el numero de guia y has clic en la LUPA.',
            ),
            if (searched != null) ...[
              const SizedBox(height: 16),
              _GuideSummary(
                guide: searched,
                style: _GuideSummaryStyle.zone,
                onOpen: () =>
                    _openGuideExplorer(searched, isQr: _lastSearchWasQr),
                onDeliver: () =>
                    _openGuideExplorer(searched, isQr: _lastSearchWasQr),
                onReturn: () => _openReturn(searched, isQr: _lastSearchWasQr),
              ),
            ],
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: _FloatingNativeButton(
            icon: Icons.search,
            tooltip: 'Actualizar zona',
            onTap: _controller.refreshInZone,
          ),
        ),
      ],
    );
  }

  Widget _guideCard(EntregaGuide guide) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: _GuideSummary(
        guide: guide,
        style: _selectedModule == _EntregaModule.enZona
            ? _GuideSummaryStyle.zone
            : _selectedModule == _EntregaModule.entregadas
            ? _GuideSummaryStyle.delivered
            : _GuideSummaryStyle.returned,
        onOpen: _selectedModule == _EntregaModule.enZona
            ? () => _openGuideExplorer(guide, isQr: false)
            : null,
        onDeliver: _selectedModule == _EntregaModule.enZona
            ? () => _openGuideExplorer(guide, isQr: false)
            : null,
        onReturn: _selectedModule == _EntregaModule.enZona
            ? () => _openReturn(guide, isQr: false)
            : null,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
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

  Future<void> _runSearch(String guide) async {
    _lastSearchWasQr = false;
    await _run(() => _controller.searchGuide(guide));
  }

  Future<void> _openQrDialog() async {
    final result = await _nativeBridge.scanQrCode();
    if (result.trim().isEmpty) return;
    _searchController.text = result.replaceAll(RegExp(r'[^0-9]'), '');
    _lastSearchWasQr = true;
    await _run(() => _controller.searchGuide(result));
  }

  Future<void> _openMultientrega() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => MultientregaPage(
          appInformation: widget.appInformation,
          apiConfig: widget.apiConfig,
          offline: widget.offline,
        ),
      ),
    );
    if (!mounted) return;
    await _controller.refreshInZone();
  }

  Future<bool> _showDeliverySheet(
    BuildContext context,
    EntregaGuide guide, {
    required bool isQr,
    int paymentMethodId = PagoMethodIds.cash,
  }) async {
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _DeliverySheet(
          controller: _controller,
          guide: guide,
          isQr: isQr,
          paymentMethodId: paymentMethodId,
        );
      },
    );
    return completed == true;
  }

  Future<bool> _showReturnSheet(
    BuildContext context,
    EntregaGuide guide, {
    required bool isQr,
  }) async {
    if (_controller.returnReasons.isEmpty) {
      await _run(_controller.loadReturnReasons);
    }
    if (!context.mounted) return false;
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _ReturnSheet(controller: _controller, guide: guide, isQr: isQr);
      },
    );
    return completed == true;
  }

  Future<void> _openGuideExplorer(
    EntregaGuide guide, {
    required bool isQr,
  }) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _EntregaExplorerPage(
          guide: guide,
          onDeliver: (context, paymentMethodId) => _showDeliverySheet(
            context,
            guide,
            isQr: isQr,
            paymentMethodId: paymentMethodId,
          ),
          onReturn: (context) => _showReturnSheet(context, guide, isQr: isQr),
        ),
      ),
    );
    if (completed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guia ${guide.guideNumber} guardada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openReturn(EntregaGuide guide, {required bool isQr}) async {
    final completed = await _showReturnSheet(context, guide, isQr: isQr);
    if (completed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Devolucion ${guide.guideNumber} guardada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _EntregaExplorerPage extends StatefulWidget {
  const _EntregaExplorerPage({
    required this.guide,
    required this.onDeliver,
    required this.onReturn,
  });

  final EntregaGuide guide;
  final Future<bool> Function(BuildContext context, int paymentMethodId)
  onDeliver;
  final Future<bool> Function(BuildContext context) onReturn;

  @override
  State<_EntregaExplorerPage> createState() => _EntregaExplorerPageState();
}

class _EntregaExplorerPageState extends State<_EntregaExplorerPage> {
  late int _selectedTab;
  int _selectedPaymentMethodId = PagoMethodIds.cash;
  bool _processing = false;

  bool get _hasChanges => _changesFor(widget.guide).isNotEmpty;
  bool get _returnToSender => _hasReturnToSenderChange(widget.guide);

  @override
  void initState() {
    super.initState();
    _selectedTab = _hasChanges ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;
    final valueToCollect = guide.valueToCollect;
    final contentVerification = _rawBool(guide.raw, 'VerificacionContenido');

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ExplorerHeader(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 10),
                  Text(
                    'Guía No. ${guide.guideNumber}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_hasChanges) ...[
                    const SizedBox(height: 12),
                    const _ExplorerNotice(
                      icon: Icons.info_outline,
                      color: AppColors.accent,
                      text:
                          'Si no es posible entregar el envío, haz la devolución con el motivo: “Cambio de domicilio”.',
                    ),
                  ],
                  const SizedBox(height: 14),
                  _ExplorerQuickActions(
                    disabled: _returnToSender,
                    onCall: _launchCall,
                    onWhatsapp: _launchWhatsapp,
                    onMap: _launchMap,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Valor a Cobrar:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _returnToSender
                          ? AppColors.gray500
                          : AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(valueToCollect),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _returnToSender
                          ? AppColors.gray500
                          : AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (valueToCollect == 0) ...[
                    const SizedBox(height: 16),
                    const _GuidePaidCard(),
                  ],
                  if (contentVerification) ...[
                    const SizedBox(height: 18),
                    const _CheckContentRow(),
                    const SizedBox(height: 12),
                    const _ExplorerNotice(
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.accent,
                      text:
                          'El destinatario podrá verificar el contenido del paquete antes de realizar el pago.',
                    ),
                  ],
                  const SizedBox(height: 18),
                  _PaymentSelector(
                    enabled: valueToCollect > 0,
                    selectedPaymentMethodId: _selectedPaymentMethodId,
                    onChanged: (value) =>
                        setState(() => _selectedPaymentMethodId = value),
                  ),
                  const SizedBox(height: 18),
                  _ExplorerTabsCard(
                    guide: guide,
                    selectedTab: _selectedTab,
                    onTabChanged: (value) =>
                        setState(() => _selectedTab = value),
                  ),
                  const SizedBox(height: 20),
                  _ExplorerPrimaryAction(
                    label: _processing ? 'Procesando' : 'Entregar',
                    filled: true,
                    enabled: !_returnToSender && !_processing,
                    onTap: () => _runDeliverAction(widget.onDeliver),
                  ),
                  const SizedBox(height: 14),
                  _ExplorerPrimaryAction(
                    label: 'Devolución',
                    filled: false,
                    enabled: !_processing,
                    onTap: () => _runAction(widget.onReturn),
                  ),
                ],
              ),
            ),
            if (_processing)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAction(
    Future<bool> Function(BuildContext context) action,
  ) async {
    setState(() => _processing = true);
    try {
      final completed = await action(context);
      if (completed && mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _runDeliverAction(
    Future<bool> Function(BuildContext context, int paymentMethodId) action,
  ) async {
    setState(() => _processing = true);
    try {
      final completed = await action(context, _selectedPaymentMethodId);
      if (completed && mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _launchCall() async {
    final phone = _cleanPhone(widget.guide.phone);
    if (phone.isEmpty) {
      _showMessage('Número de teléfono inválido.');
      return;
    }
    await _launchExternal(
      Uri(scheme: 'tel', path: phone),
      'No fue posible llamar.',
    );
  }

  Future<void> _launchWhatsapp() async {
    final phone = _whatsappPhone(widget.guide.phone);
    if (phone.isEmpty) {
      _showMessage('Número de WhatsApp inválido.');
      return;
    }
    final message = widget.guide.valueToCollect > 0
        ? 'Hola, somos Inter Rapidísimo. Vamos en camino para entregar tu envío ${widget.guide.guideNumber}. Valor a cobrar ${_formatCurrency(widget.guide.valueToCollect)}.'
        : 'Hola, somos Inter Rapidísimo. Vamos en camino para entregar tu envío ${widget.guide.guideNumber}.';
    await _launchExternal(
      Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}'),
      'No se encontró WhatsApp.',
    );
  }

  Future<void> _launchMap() async {
    final latitude = widget.guide.latitude.trim();
    final longitude = widget.guide.longitude.trim();
    if (latitude.isEmpty || longitude.isEmpty) {
      _showMessage('La guía no tiene coordenadas disponibles.');
      return;
    }
    await _launchExternal(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      ),
      'No fue posible abrir el mapa.',
    );
  }

  Future<void> _launchExternal(Uri uri, String fallback) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) _showMessage(fallback);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ExplorerHeader extends StatelessWidget {
  const _ExplorerHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -12,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.black),
              tooltip: 'Atras',
            ),
          ),
          const Text(
            'Entregar',
            style: TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplorerQuickActions extends StatelessWidget {
  const _ExplorerQuickActions({
    required this.disabled,
    required this.onCall,
    required this.onWhatsapp,
    required this.onMap,
  });

  final bool disabled;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ExplorerActionTile(
            icon: Icons.call_outlined,
            label: 'Llamar',
            disabled: disabled,
            onTap: onCall,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ExplorerActionTile(
            icon: Icons.chat_bubble_outline,
            label: 'Whatsapp',
            disabled: disabled,
            onTap: onWhatsapp,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ExplorerActionTile(
            icon: Icons.map_outlined,
            label: 'Mapa',
            disabled: disabled,
            onTap: onMap,
          ),
        ),
      ],
    );
  }
}

class _ExplorerActionTile extends StatelessWidget {
  const _ExplorerActionTile({
    required this.icon,
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = disabled ? AppColors.gray500 : AppColors.black;
    return Material(
      color: AppColors.white,
      elevation: 4,
      shadowColor: AppColors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplorerNotice extends StatelessWidget {
  const _ExplorerNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePaidCard extends StatelessWidget {
  const _GuidePaidCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F8F4),
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, color: AppColors.green, size: 34),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Esta guía ya está paga',
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 16,
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

class _CheckContentRow extends StatelessWidget {
  const _CheckContentRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Verificar contenido',
          style: TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 8),
        Icon(Icons.inventory_2_outlined, color: AppColors.black),
      ],
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({
    required this.enabled,
    required this.selectedPaymentMethodId,
    required this.onChanged,
  });

  final bool enabled;
  final int selectedPaymentMethodId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = enabled
        ? PagoMethodIds.nameFor(selectedPaymentMethodId)
        : 'Pago confirmado';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? AppColors.white : AppColors.gray100,
        border: Border.all(color: AppColors.gray300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.payments_outlined : Icons.check_circle_outline,
              color: AppColors.black,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuButton<int>(
              enabled: enabled,
              tooltip: 'Metodo de pago',
              onSelected: onChanged,
              itemBuilder: (context) => [
                for (final method in PagoMethodIds.chargeable)
                  PopupMenuItem<int>(
                    value: method,
                    child: Text(PagoMethodIds.nameFor(method)),
                  ),
              ],
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorerTabsCard extends StatelessWidget {
  const _ExplorerTabsCard({
    required this.guide,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final EntregaGuide guide;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final changes = _changesFor(guide);
    final returnToSender = _hasReturnToSenderChange(guide);
    final accent = selectedTab == 1
        ? returnToSender
              ? AppColors.red
              : const Color(0xFFF2A900)
        : AppColors.black;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ExplorerTabButton(
                label: 'Datos destinatario',
                selected: selectedTab == 0,
                onTap: () => onTabChanged(0),
              ),
            ),
            Expanded(
              child: _ExplorerTabButton(
                label: 'Cambios',
                selected: selectedTab == 1,
                badge: changes.length,
                disabled: changes.isEmpty,
                danger: returnToSender,
                onTap: () => onTabChanged(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: selectedTab == 1 && changes.isNotEmpty && !returnToSender
                ? const Color(0xFFFFF8E1)
                : AppColors.white,
            border: Border.all(color: accent, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: selectedTab == 0
                  ? _GuideDataPanel(guide: guide)
                  : _ChangesPanel(changes: changes),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExplorerTabButton extends StatelessWidget {
  const _ExplorerTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
    this.disabled = false,
    this.danger = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;
  final bool disabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? AppColors.gray500
        : selected
        ? AppColors.black
        : AppColors.gray700;
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: danger ? AppColors.red : const Color(0xFFF2A900),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? AppColors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideDataPanel extends StatelessWidget {
  const _GuideDataPanel({required this.guide});

  final EntregaGuide guide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NativeLabelValue(label: 'Número guía', value: guide.guideNumber),
        const SizedBox(height: 8),
        _NativeLabelValue(label: 'Nombre cliente', value: guide.recipientName),
        const SizedBox(height: 8),
        _NativeLabelValue(label: 'Dirección', value: guide.recipientAddress),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NativeLabelValue(
                label: 'Peso',
                value: '${guide.weight} Kg',
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NativeLabelValue(
                label: 'Celular',
                value: guide.phone,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _NativeLabelValue(
          label: 'Tipo servicio',
          value: guide.serviceName.isEmpty
              ? 'Tipo servicio'
              : guide.serviceName,
        ),
      ],
    );
  }
}

class _ChangesPanel extends StatelessWidget {
  const _ChangesPanel({required this.changes});

  final List<_ExplorerChange> changes;

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 26),
          child: Text(
            'Sin cambios registrados',
            style: TextStyle(
              color: AppColors.gray700,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < changes.length; index++) ...[
          _ChangeTile(change: changes[index]),
          if (index != changes.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.gray300),
            ),
        ],
      ],
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.change});

  final _ExplorerChange change;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          change.danger ? Icons.assignment_return_outlined : Icons.sync_alt,
          color: change.danger ? AppColors.red : AppColors.black,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                change.title,
                style: TextStyle(
                  color: change.danger ? AppColors.red : AppColors.black,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (change.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  change.description,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
              if (change.dateText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Fecha del cambio: ${change.dateText}',
                  style: const TextStyle(
                    color: AppColors.gray700,
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExplorerPrimaryAction extends StatelessWidget {
  const _ExplorerPrimaryAction({
    required this.label,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = filled ? AppColors.black : AppColors.white;
    final foreground = filled ? AppColors.white : AppColors.black;
    return Material(
      color: enabled ? background : AppColors.gray200,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: filled ? null : Border.all(color: AppColors.black),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? foreground : AppColors.gray500,
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplorerChange {
  const _ExplorerChange({
    required this.title,
    required this.description,
    required this.dateText,
    this.danger = false,
  });

  final String title;
  final String description;
  final String dateText;
  final bool danger;
}

List<_ExplorerChange> _changesFor(EntregaGuide guide) {
  final changes = _rawMap(guide.raw['Cambios']);
  final items = <_ExplorerChange>[];

  void addChange(
    String key,
    String title,
    String Function(Map<String, dynamic> value) description, {
    bool danger = false,
  }) {
    final value = _rawMap(changes[key]);
    if (value.isEmpty) return;
    items.add(
      _ExplorerChange(
        title: title,
        description: description(value),
        dateText: _formatChangeDate(_rawString(value, 'Datetime')),
        danger: danger,
      ),
    );
  }

  addChange(
    'CambioDireccion',
    'Cambio de dirección',
    (value) => _rawString(value, 'Direccion'),
  );
  addChange('CambioAutorizaVecino', 'Autorización vecino', (value) {
    final name = _rawString(value, 'Nombre');
    final location = _rawString(value, 'Ubicacion');
    return [name, location].where((item) => item.isNotEmpty).join(' - ');
  });
  addChange('CambioDestinatario', 'Cambio destinatario', (value) {
    final name = _rawString(value, 'Nombre');
    final address = _rawString(value, 'Direccion');
    final phone = _rawString(value, 'TelefonoDestinatario');
    return [name, address, phone].where((item) => item.isNotEmpty).join(' - ');
  });
  addChange(
    'CambioDevolverARemitente',
    'Devolver al remitente',
    (_) => 'El último cambio solicita devolver el envío al remitente.',
    danger: true,
  );
  addChange(
    'UltimaDireccionLogisticaInversa',
    'Última dirección logística inversa',
    (value) => _rawString(value, 'UltimaDireccion'),
  );
  addChange('AutorizaTerceroRO', 'Autoriza tercero RO', (value) {
    final name = _rawString(value, 'NombreTercero');
    final document = _rawString(
      value,
      'IdentificacionTercero',
    ).replaceAll('Numero de Identificacion:', '').trim();
    return [name, document].where((item) => item.isNotEmpty).join(' - ');
  });
  addChange(
    'CambioReclamoEnOficina',
    'Solicitud reclamo en oficina',
    (value) => _rawString(value, 'NombreCentroServicios'),
  );
  addChange(
    'CambioPagoAnticipado',
    'Cambio pago anticipado',
    (_) => 'El destinatario registró una solicitud de pago anticipado.',
  );

  final telemercadeo = _rawMap(guide.raw['Telemercadeo']);
  if (telemercadeo.isNotEmpty) {
    items.add(
      _ExplorerChange(
        title: 'Telemercadeo',
        description: _rawString(telemercadeo, 'NuevaDireccionTelemercadeo'),
        dateText: _formatChangeDate(_rawString(telemercadeo, 'Datetime')),
      ),
    );
  }

  return items;
}

bool _hasReturnToSenderChange(EntregaGuide guide) {
  return _rawMap(
    _rawMap(guide.raw['Cambios'])['CambioDevolverARemitente'],
  ).isNotEmpty;
}

Map<String, dynamic> _rawMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, child) => MapEntry(key.toString(), child));
  }
  return const {};
}

String _rawString(Map<String, dynamic> json, String key) {
  return (json[key] ?? '').toString().trim();
}

bool _rawBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = (value ?? '').toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'si';
}

String _cleanPhone(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

String _whatsappPhone(String value) {
  final phone = _cleanPhone(value);
  if (phone.length == 10 && phone.startsWith('3')) return '57$phone';
  return phone;
}

String _formatCurrency(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final remaining = rounded.length - i;
    buffer.write(rounded[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return '\$ ${value < 0 ? '-' : ''}${buffer.toString()}';
}

String _formatChangeDate(String value) {
  if (value.isEmpty) return '';
  try {
    final date = DateTime.parse(value.replaceFirst(' ', 'T'));
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  } catch (_) {
    return value;
  }
}

class _EntregasBanner extends StatefulWidget {
  const _EntregasBanner({required this.controller});

  final EntregasController controller;

  @override
  State<_EntregasBanner> createState() => _EntregasBannerState();
}

class _EntregasBannerState extends State<_EntregasBanner> {
  Timer? _visibilityTimer;
  bool _timeExpired = false;

  final Duration _durationVisible = const Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _EntregasBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldText =
        oldWidget.controller.errorMessage ?? oldWidget.controller.statusMessage;
    final currentText =
        widget.controller.errorMessage ?? widget.controller.statusMessage;

    final textChanged =
        oldText != currentText ||
        oldWidget.controller.syncing != widget.controller.syncing;

    final isNewTrigger =
        widget.controller.syncing == false && currentText.trim().isNotEmpty;

    if (textChanged || isNewTrigger) {
      setState(() {
        _timeExpired = false;
      });
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _visibilityTimer?.cancel();

    final text =
        widget.controller.errorMessage ?? widget.controller.statusMessage;
    if (!widget.controller.syncing && text.trim().isNotEmpty) {
      _visibilityTimer = Timer(_durationVisible, () {
        if (mounted) {
          setState(() {
            _timeExpired = true;
          });
        }
      });
    }
  }

  void _ocultarManualmente() {
    _visibilityTimer?.cancel();
    setState(() {
      _timeExpired = true;
    });
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text =
        widget.controller.errorMessage ?? widget.controller.statusMessage;

    if (text.trim().isEmpty && !widget.controller.syncing) {
      return const SizedBox.shrink();
    }

    final error = widget.controller.errorMessage != null;

    return AnimatedOpacity(
      opacity: _timeExpired ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Visibility(
        visible: !_timeExpired,
        maintainState: true,
        child: GestureDetector(
          onTap: _ocultarManualmente,
          child: Material(
            color: error ? const Color(0xFFFACDD8) : AppColors.accentLight,
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    color: error ? AppColors.red : AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  if (widget.controller.syncing) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    const SizedBox(width: 10),
                  ] else
                    Icon(
                      error ? Icons.cancel_outlined : Icons.info_outline,
                      color: AppColors.black,
                      size: 22,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntregasNativeHeader extends StatelessWidget {
  const _EntregasNativeHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppColors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.black),
            tooltip: 'Atras',
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopShadow extends StatelessWidget {
  const _TopShadow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.black.withValues(alpha: 0.10),
            AppColors.black.withValues(alpha: 0.00),
          ],
        ),
      ),
      child: const SizedBox(height: 10),
    );
  }
}

class _EntregasBottomTabs extends StatelessWidget {
  const _EntregasBottomTabs({
    required this.selected,
    required this.inZoneCount,
    required this.deliveredCount,
    required this.returnedCount,
    required this.loading,
    required this.onSelected,
  });

  final _EntregaModule selected;
  final int inZoneCount;
  final int deliveredCount;
  final int returnedCount;
  final bool loading;
  final ValueChanged<_EntregaModule> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Row(
        children: [
          _BottomTabItem(
            selected: selected == _EntregaModule.buscar,
            icon: Icons.search,
            label: 'Buscar',
            onTap: () => onSelected(_EntregaModule.buscar),
          ),
          _BottomTabItem(
            selected: selected == _EntregaModule.enZona,
            icon: Icons.location_on_outlined,
            count: inZoneCount,
            loading: loading,
            label: 'Zona',
            onTap: () => onSelected(_EntregaModule.enZona),
          ),
          _BottomTabItem(
            selected: selected == _EntregaModule.entregadas,
            icon: Icons.inventory_2_outlined,
            count: deliveredCount,
            loading: loading,
            label: 'Entregadas',
            onTap: () => onSelected(_EntregaModule.entregadas),
          ),
          _BottomTabItem(
            selected: selected == _EntregaModule.devolucion,
            icon: Icons.assignment_return_outlined,
            count: returnedCount,
            loading: loading,
            label: 'Devolucion',
            onTap: () => onSelected(_EntregaModule.devolucion),
          ),
        ],
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.loading = false,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.gray100 : AppColors.white,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (selected)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 3,
                    child: ColoredBox(color: AppColors.black),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: AppColors.black, size: 22),
                        if (count != null) ...[
                          const SizedBox(width: 5),
                          if (loading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Text(
                              '$count',
                              style: const TextStyle(
                                color: AppColors.black,
                                fontFamily: 'Montserrat',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryModeSwitch extends StatelessWidget {
  const _DeliveryModeSwitch({required this.onMultiple});

  final VoidCallback onMultiple;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Individual',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onMultiple,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    'Multiple',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

class _NativeSearchField extends StatelessWidget {
  const _NativeSearchField({
    required this.controller,
    required this.onQr,
    required this.onSearch,
  });

  final TextEditingController controller;
  final VoidCallback onQr;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.gray300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 14,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'Ingrese # de guia',
                filled: false,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.only(left: 20, right: 12),
                hintStyle: TextStyle(color: AppColors.gray500, fontSize: 16),
              ),
            ),
          ),
          IconButton(
            onPressed: onQr,
            tooltip: 'Escanear',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.black,
              foregroundColor: AppColors.white,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onSearch,
            tooltip: 'Buscar',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.black,
              foregroundColor: AppColors.white,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.search),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _NativeInfoLegend extends StatelessWidget {
  const _NativeInfoLegend({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.gray700,
        fontFamily: 'Montserrat',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black,
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Filtro',
                style: TextStyle(color: AppColors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshChip extends StatelessWidget {
  const _RefreshChip({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: IconButton(
        tooltip: 'Actualizar',
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, color: AppColors.black),
      ),
    );
  }
}

class _ZoneActionDock extends StatelessWidget {
  const _ZoneActionDock({
    required this.syncing,
    required this.onSync,
    required this.onRefresh,
    required this.onScan,
  });

  final bool syncing;
  final VoidCallback onSync;
  final Future<void> Function() onRefresh;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FloatingNativeButton(
          icon: Icons.menu,
          tooltip: 'Menu zona',
          onTap: onRefresh,
        ),
        const SizedBox(width: 8),
        _FloatingNativeButton(
          icon: syncing ? Icons.sync_lock : Icons.sync,
          tooltip: 'Sincronizar',
          onTap: syncing ? null : onSync,
        ),
        const SizedBox(width: 8),
        _FloatingNativeButton(
          icon: Icons.route_outlined,
          tooltip: 'Enrutar',
          onTap: onRefresh,
        ),
        const SizedBox(width: 8),
        _FloatingNativeButton(
          icon: Icons.qr_code_scanner,
          tooltip: 'Consultar orden',
          onTap: onScan,
        ),
      ],
    );
  }
}

class _FloatingNativeButton extends StatelessWidget {
  const _FloatingNativeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.accentLight,
        elevation: 6,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
        ),
      ),
    );
  }
}

class _NativeLoadingList extends StatelessWidget {
  const _NativeLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 60, bottom: 92),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SizedBox(height: 118),
          ),
        );
      },
    );
  }
}

enum _GuideSummaryStyle { zone, delivered, returned }

class _GuideSummary extends StatelessWidget {
  const _GuideSummary({
    required this.guide,
    required this.style,
    this.onOpen,
    this.onDeliver,
    this.onReturn,
  });

  final EntregaGuide guide;
  final _GuideSummaryStyle style;
  final VoidCallback? onOpen;
  final VoidCallback? onDeliver;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    if (style == _GuideSummaryStyle.delivered) {
      return _DeliveredGuideCard(guide: guide);
    }
    if (style == _GuideSummaryStyle.returned) {
      return _ReturnedGuideCard(guide: guide);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Material(
        color: AppColors.white,
        elevation: 10,
        shadowColor: AppColors.gray700.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 18, 15, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 125,
                      child: Text(
                        guide.guideNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'peso',
                      style: TextStyle(
                        color: AppColors.gray500,
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${guide.weight.toStringAsFixed(guide.weight.truncateToDouble() == guide.weight ? 0 : 1)}Kg',
                      style: const TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RouteNumberBadge(value: guide.planSheet),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  guide.recipientAddress.trim().isEmpty
                      ? 'Direccion no disponible'
                      : guide.recipientAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'A Cobrar',
                            style: TextStyle(
                              color: AppColors.gray500,
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatMoney(guide.valueToCollect),
                            style: const TextStyle(
                              color: AppColors.black,
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onDeliver != null || onReturn != null)
                      Wrap(
                        spacing: 5,
                        children: [
                          _NativeSmallButton(
                            label: 'Entregar',
                            filled: true,
                            onTap: onDeliver,
                          ),
                          _NativeSmallButton(
                            label: 'Devolver',
                            filled: false,
                            onTap: onReturn,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMoney(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    return '\$ ${buffer.toString()}';
  }
}

class _DeliveredGuideCard extends StatelessWidget {
  const _DeliveredGuideCard({required this.guide});

  final EntregaGuide guide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      guide.guideNumber,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guide.recipientAddress,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      guide.recipientName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${guide.weight} Kg - ${guide.serviceName.isEmpty ? 'Caja' : guide.serviceName}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: AppColors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnedGuideCard extends StatelessWidget {
  const _ReturnedGuideCard({required this.guide});

  final EntregaGuide guide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
      child: Material(
        color: AppColors.white,
        elevation: 8,
        shadowColor: AppColors.gray700.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                guide.guideNumber,
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _NativeLabelValue(
                      label: 'Nombre Cliente',
                      value: guide.recipientName,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.assignment_return_outlined,
                    color: AppColors.red,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _NativeLabelValue(
                label: 'Direccion',
                value: guide.recipientAddress,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _NativeLabelValue(
                    label: 'peso',
                    value: '${guide.weight}Kg',
                    compact: true,
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 34, color: AppColors.gray200),
                  const SizedBox(width: 10),
                  _NativeLabelValue(
                    label: 'A Cobrar',
                    value: '\$ ${guide.valueToCollect}',
                    compact: true,
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

class _RouteNumberBadge extends StatelessWidget {
  const _RouteNumberBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 37, minHeight: 22),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.black),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value <= 0 ? '-' : '$value',
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NativeSmallButton extends StatelessWidget {
  const _NativeSmallButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.black : AppColors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: filled ? null : Border.all(color: AppColors.black),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? AppColors.white : AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _NativeLabelValue extends StatelessWidget {
  const _NativeLabelValue({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? null : double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.gray500,
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value.trim().isEmpty ? '-' : value,
            maxLines: compact ? 1 : 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverySheet extends StatefulWidget {
  const _DeliverySheet({
    required this.controller,
    required this.guide,
    required this.isQr,
    required this.paymentMethodId,
  });

  final EntregasController controller;
  final EntregaGuide guide;
  final bool isQr;
  final int paymentMethodId;

  @override
  State<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends State<_DeliverySheet> {
  final _nameController = TextEditingController();
  final _documentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _observationController = TextEditingController();
  final _signatureKey = GlobalKey<_SignaturePadState>();
  final _nativeBridge = ControllerNativeBridge();
  bool _saving = false;
  String _photoBase64 = '';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.guide.recipientName;
    _phoneController.text = widget.guide.phone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _documentController.dispose();
    _phoneController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'ENTREGAS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeliveryGuideHeader(guide: widget.guide),
          if (widget.guide.valueToCollect > 0) ...[
            const SizedBox(height: 12),
            _DeliveryPaymentNotice(
              methodId: widget.paymentMethodId,
              valueToCollect: widget.guide.valueToCollect,
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            decoration: _lightInputDecoration(
              'Nombre de quien recibe',
              Icons.person,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _documentController,
            decoration: _lightInputDecoration('Documento', Icons.badge),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            decoration: _lightInputDecoration('Teléfono', Icons.phone),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _observationController,
            decoration: _lightInputDecoration(
              'Observaciones (Opcional)',
              Icons.notes,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const _SignatureWarning(),
          const SizedBox(height: 14),
          const _LightSectionLabel(
            icon: Icons.draw_outlined,
            label: 'Firma recibido',
          ),
          const SizedBox(height: 8),
          _SignaturePad(key: _signatureKey),
          const SizedBox(height: 14),
          const _LightSectionLabel(
            icon: Icons.photo_camera_outlined,
            label: 'Foto paquete',
          ),
          const SizedBox(height: 8),
          _photoCapture(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _NativeSheetButton(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: _photoBase64.trim().isEmpty ? 'Foto' : 'Repetir',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NativeSheetButton(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: _saving ? 'Guardando' : 'Guardar',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoCapture() {
    final bytes = _photoBytes();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.gray100,
        border: Border.all(color: AppColors.gray300, width: 1.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: bytes == null
            ? const SizedBox(
                height: 112,
                child: Center(
                  child: Text(
                    'Sin foto de entrega',
                    style: TextStyle(
                      color: AppColors.gray700,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(bytes, height: 150, fit: BoxFit.cover),
              ),
      ),
    );
  }

  Uint8List? _photoBytes() {
    if (_photoBase64.trim().isEmpty) return null;
    try {
      return base64Decode(_cleanBase64(_photoBase64));
    } on Object {
      return null;
    }
  }

  Future<void> _takePhoto() async {
    final photo = await _nativeBridge.takePackagePhoto();
    final jpegPhoto = await _ensureJpegImage(
      photo,
      maxDimension: 480,
      quality: 35,
      maxBase64Length: 45 * 1024,
    );
    if (!mounted) return;
    if (jpegPhoto.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible capturar la foto en formato JPEG.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _photoBase64 = jpegPhoto);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final signatureCapture =
          await _signatureKey.currentState?.capture() ?? '';
      final signature = await _ensureJpegImage(
        signatureCapture,
        maxDimension: 420,
        quality: 35,
        maxBase64Length: 10 * 1024,
      );
      if (signatureCapture.trim().isNotEmpty && signature.trim().isEmpty) {
        throw const EntregaException(
          'No fue posible convertir la firma a JPEG.',
        );
      }
      await widget.controller.completeDelivery(
        guide: widget.guide,
        recipient: EntregaRecipientData(
          name: _nameController.text.trim(),
          document: _documentController.text.trim(),
          phone: _phoneController.text.trim(),
          observations: _observationController.text.trim(),
          housingTypeId: widget.guide.housingTypeId,
        ),
        signatureBase64: signature,
        photoBase64: _photoBase64,
        isQr: widget.isQr,
        paymentMethodId: widget.paymentMethodId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _ensureJpegImage(
    String imageBase64, {
    required int maxDimension,
    required int quality,
    required int maxBase64Length,
  }) async {
    final cleanImage = _cleanBase64(imageBase64);
    if (cleanImage.isEmpty) return '';
    final converted = await _nativeBridge.compressImageBase64ToJpeg(
      cleanImage,
      maxDimension: maxDimension,
      quality: quality,
      maxBase64Length: maxBase64Length,
    );
    final cleanConverted = _cleanBase64(converted);
    if (_isJpegBase64(cleanConverted) &&
        cleanConverted.length <= maxBase64Length) {
      return cleanConverted;
    }
    if (_isJpegBase64(cleanImage) && cleanImage.length <= maxBase64Length) {
      return cleanImage;
    }
    return '';
  }

  bool _isJpegBase64(String imageBase64) {
    try {
      final bytes = base64Decode(_cleanBase64(imageBase64));
      return bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    } on Object {
      return false;
    }
  }

  String _cleanBase64(String value) {
    return value
        .split('base64,')
        .last
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
  }

  InputDecoration _lightInputDecoration(String label, IconData icon) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.gray500, width: 1.2),
    );
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, color: AppColors.black),
      hintStyle: const TextStyle(
        color: AppColors.gray500,
        fontFamily: 'Montserrat',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.black, width: 1.5),
      ),
    );
  }
}

class _ReturnSheet extends StatefulWidget {
  const _ReturnSheet({
    required this.controller,
    required this.guide,
    required this.isQr,
  });

  final EntregasController controller;
  final EntregaGuide guide;
  final bool isQr;

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  final _observationController = TextEditingController();
  EntregaReason? _reason;
  bool _saving = false;

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Devolucion',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReturnGuideHeader(guideNumber: widget.guide.guideNumber),
          const SizedBox(height: 18),
          DropdownButtonFormField<EntregaReason>(
            initialValue: _reason,
            decoration: _lightInputDecoration(
              'Motivo',
              Icons.assignment_return_outlined,
            ),
            items: widget.controller.returnReasons
                .map(
                  (reason) => DropdownMenuItem(
                    value: reason,
                    child: Text(reason.description),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _reason = value),
          ),
          const SizedBox(height: 10),
          const Text(
            'Observaciones',
            style: TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _observationController,
            decoration: _lightInputDecoration(
              'Ingrese observaciones',
              Icons.notes_outlined,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          _NativeSheetButton(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.save_outlined),
            label: _saving ? 'Guardando' : 'Finalizar',
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un motivo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.completeReturn(
        guide: widget.guide,
        reason: reason,
        observations: _observationController.text.trim(),
        isQr: widget.isQr,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _lightInputDecoration(String label, IconData icon) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: AppColors.gray500, width: 1.4),
    );
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, color: AppColors.black),
      hintStyle: const TextStyle(
        color: AppColors.gray500,
        fontFamily: 'Montserrat',
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.black, width: 1.6),
      ),
    );
  }
}

class _DeliveryGuideHeader extends StatelessWidget {
  const _DeliveryGuideHeader({required this.guide});

  final EntregaGuide guide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Generar firma',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.accent,
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Nro. Guía',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          guide.guideNumber,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          guide.serviceName.trim().isEmpty
              ? 'Tipo servicio'
              : guide.serviceName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.accent,
            fontFamily: 'Montserrat',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DeliveryPaymentNotice extends StatelessWidget {
  const _DeliveryPaymentNotice({
    required this.methodId,
    required this.valueToCollect,
  });

  final int methodId;
  final int valueToCollect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF2A900)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.payments_outlined, color: AppColors.black),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cobro ${PagoMethodIds.nameFor(methodId)} por ${_formatCurrency(valueToCollect)}',
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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

class _ReturnGuideHeader extends StatelessWidget {
  const _ReturnGuideHeader({required this.guideNumber});

  final String guideNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Guia No.',
          style: TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 21,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            guideNumber,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
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
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.black, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Es muy importante que se solicite la firma al cliente y que sea válida para el registro de la prueba de entrega.',
                style: TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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

class _LightSectionLabel extends StatelessWidget {
  const _LightSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.black),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
  Size _lastSize = const Size(320, 160);

  bool get hasSignature => _points.whereType<Offset>().length > 1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastSize = Size(constraints.maxWidth, 170);
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
                    top: 6,
                    child: IconButton.filledTonal(
                      onPressed: _maximize,
                      tooltip: 'Maximizar firma',
                      icon: const Icon(Icons.open_in_full),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
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
    final normalized = Offset(offset.dx / width, offset.dy / height);
    setState(() => _points.add(normalized));
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
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current == null || next == null) continue;
      canvas.drawLine(
        Offset(current.dx * size.width, current.dy * size.height),
        Offset(next.dx * size.width, next.dy * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return true;
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _NativeSheetHeader(title: title),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _NativeSheetHeader extends StatelessWidget {
  const _NativeSheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          Positioned(
            left: -12,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.arrow_back, color: AppColors.black),
              tooltip: 'Atras',
            ),
          ),
        ],
      ),
    );
  }
}

class _NativeSheetButton extends StatelessWidget {
  const _NativeSheetButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.gray500,
        disabledForegroundColor: AppColors.white,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        textStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: icon,
      label: Text(label),
    );
  }
}

class _EntregasEmptyState extends StatelessWidget {
  const _EntregasEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
