import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../shared/native/controller_native_bridge.dart';
import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
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
            _DeliveryModeSwitch(
              onMultiple: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Multientrega no disponible por ahora.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
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
                onDeliver: () =>
                    _openDelivery(searched, isQr: _lastSearchWasQr),
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
        onDeliver: _selectedModule == _EntregaModule.enZona
            ? () => _openDelivery(guide, isQr: false)
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

  Future<void> _openDelivery(EntregaGuide guide, {required bool isQr}) async {
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _DeliverySheet(
          controller: _controller,
          guide: guide,
          isQr: isQr,
        );
      },
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
    if (_controller.returnReasons.isEmpty) {
      await _run(_controller.loadReturnReasons);
    }
    if (!mounted) return;
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _ReturnSheet(controller: _controller, guide: guide, isQr: isQr);
      },
    );
    if (completed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Devolucion ${guide.guideNumber} guardada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

    final oldText = oldWidget.controller.errorMessage ?? oldWidget.controller.statusMessage;
    final currentText = widget.controller.errorMessage ?? widget.controller.statusMessage;

    final textChanged = oldText != currentText || oldWidget.controller.syncing != widget.controller.syncing;
    
    final isNewTrigger = widget.controller.syncing == false && currentText.trim().isNotEmpty;

    if (textChanged || isNewTrigger) {
      setState(() {
        _timeExpired = false; 
      });
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _visibilityTimer?.cancel();

    final text = widget.controller.errorMessage ?? widget.controller.statusMessage;
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
    final text = widget.controller.errorMessage ?? widget.controller.statusMessage;

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
    this.onDeliver,
    this.onReturn,
  });

  final EntregaGuide guide;
  final _GuideSummaryStyle style;
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
  });

  final EntregasController controller;
  final EntregaGuide guide;
  final bool isQr;

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
      title: 'Entrega Correcta',
      dark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeliveryGuideHeader(guide: widget.guide),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: _darkInputDecoration('Recibido por', Icons.person),
            style: _darkInputStyle,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _documentController,
            decoration: _darkInputDecoration('No. Identificacion', Icons.badge),
            style: _darkInputStyle,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            decoration: _darkInputDecoration('Telefono', Icons.phone),
            style: _darkInputStyle,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _observationController,
            decoration: _darkInputDecoration('Observaciones', Icons.notes),
            style: _darkInputStyle,
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          _SectionLabel(icon: Icons.draw_outlined, label: 'Firma'),
          const SizedBox(height: 8),
          _SignaturePad(key: _signatureKey),
          const SizedBox(height: 14),
          _SectionLabel(
            icon: Icons.photo_camera_outlined,
            label: 'Foto paquete',
          ),
          const SizedBox(height: 8),
          _photoCapture(),
          const SizedBox(height: 16),
          _NativeSheetButton(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.save_outlined),
            label: _saving ? 'Guardando' : 'Guardar',
            inverted: true,
          ),
        ],
      ),
    );
  }

  Widget _photoCapture() {
    final bytes = _photoBytes();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        border: Border.all(color: const Color(0xAAFFFFFF), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(bytes, height: 150, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            _NativeSheetButton(
              onPressed: _takePhoto,
              icon: const Icon(Icons.photo_camera),
              label: bytes == null ? 'Captura Guia' : 'Repetir Foto',
              inverted: true,
            ),
          ],
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

  TextStyle get _darkInputStyle {
    return const TextStyle(
      color: AppColors.white,
      fontFamily: 'Montserrat',
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );
  }

  InputDecoration _darkInputDecoration(String label, IconData icon) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xAAFFFFFF), width: 1.5),
    );
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, color: const Color(0xAAFFFFFF)),
      hintStyle: const TextStyle(
        color: Color(0xAA9E9E9E),
        fontFamily: 'Montserrat',
        fontSize: 18,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: const Color(0xAA000000),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.white, width: 1.5),
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
          'Entrega Correcta',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.white,
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Nro. Guia',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.white,
            fontFamily: 'Montserrat',
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          guide.guideNumber,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.white,
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
            color: AppColors.white,
            fontFamily: 'Montserrat',
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
            child: Stack(
              children: [
                GestureDetector(
                  onPanStart: (details) => _addPoint(details.localPosition),
                  onPanUpdate: (details) => _addPoint(details.localPosition),
                  onPanEnd: (_) => _addPoint(null),
                  child: CustomPaint(
                    painter: _SignaturePainter(_points),
                    size: Size.infinite,
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

  void _addPoint(Offset? offset) {
    setState(() => _points.add(offset));
  }

  void _clear() {
    setState(_points.clear);
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current == null || next == null) continue;
      canvas.drawLine(current, next, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return true;
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.child,
    this.dark = false,
  });

  final String title;
  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final background = dark ? AppColors.black : AppColors.white;
    return Material(
      color: background,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, dark ? 10 : 0, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _NativeSheetHeader(title: title, dark: dark),
              SizedBox(height: dark ? 14 : 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _NativeSheetHeader extends StatelessWidget {
  const _NativeSheetHeader({required this.title, required this.dark});

  final String title;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (!dark) {
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
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: IconButton.styleFrom(backgroundColor: AppColors.black),
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          tooltip: 'Atras',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.white),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NativeSheetButton extends StatelessWidget {
  const _NativeSheetButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.inverted = false,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.gray500,
        disabledForegroundColor: AppColors.white,
        side: inverted
            ? const BorderSide(color: Color(0xAAFFFFFF), width: 1)
            : BorderSide.none,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
