import 'package:flutter/material.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../models/recoger_models.dart';
import 'controllers/recoger_controller.dart';

class RecogerPage extends StatefulWidget {
  const RecogerPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<RecogerPage> createState() => _RecogerPageState();
}

class _RecogerPageState extends State<RecogerPage> {
  late final RecogerController _controller;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = RecogerController(
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
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.showPreenvios) {
      return _PreenviosView(
        searchController: _searchController,
        preenvios: _controller.preenvios,
        loading: _controller.syncing,
        statusMessage: _controller.statusMessage,
        errorMessage: _controller.errorMessage,
        billingMessage: _controller.lastBillingResult?.message ?? '',
        onBack: _controller.closePreguides,
        onSearch: _controller.searchPreguide,
        onScan: _scanPreguide,
        onAddSale: _openAddSale,
        onBilling: _controller.executeBilling,
      );
    }
    return ColoredBox(
      color: AppColors.white,
      child: Column(
        children: [
          _RecogerHeader(onBack: () => Navigator.of(context).maybePop()),
          _RecogerTabs(
            selected: _controller.selectedTab,
            disponibles: _controller.disponibles.length,
            reservadas: _controller.reservadas.length,
            efectivas: _controller.efectivas.length,
            onSelected: _controller.selectTab,
          ),
          if (_controller.loading || _controller.syncing)
            const LinearProgressIndicator(minHeight: 2),
          _RecogerStatusBanner(
            message: _controller.statusMessage,
            error: _controller.errorMessage,
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_controller.selectedTab) {
      case RecogerTab.disponibles:
        return _RecogidasList(
          title: 'Recogidas disponibles',
          counter: _controller.disponibles.length,
          items: _controller.disponibles,
          emptyMessage: 'No hay recogidas disponibles para mostrar.',
          onRefresh: _controller.refreshCurrent,
          onOpenPreenvios: _confirmAssignAvailable,
        );
      case RecogerTab.reservadas:
        return _RecogidasList(
          title: 'Recogidas reservadas',
          counter: _controller.reservadas.length,
          items: _controller.reservadas,
          emptyMessage: 'No hay recogidas reservadas para mostrar.',
          onRefresh: _controller.refreshCurrent,
          onOpenPreenvios: _controller.openPreguides,
        );
      case RecogerTab.efectivas:
        return _RecogidasList(
          title: 'Recogidas efectivas',
          counter: _controller.efectivas.length,
          items: _controller.efectivas,
          emptyMessage: 'No hay recogidas efectivas para mostrar.',
          showSyncActions: true,
          onRefresh: _controller.refreshCurrent,
          onOpenPreenvios: _controller.openPreguides,
        );
    }
  }

  Future<void> _confirmAssignAvailable(RecogidaItem pickup) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssignPickupSheet(pickup: pickup),
    );
    if (ok == true) {
      await _controller.assignAvailable(pickup);
    }
  }

  Future<void> _scanPreguide() async {
    final value = await _manualGuideDialog(
      title: 'Escanear preenvio',
      hint: 'Numero leido del QR',
    );
    if (value != null) await _controller.searchPreguide(value);
  }

  Future<void> _openAddSale() async {
    final pickup = _controller.selectedPickup;
    if (pickup == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Agregar nueva venta usa el flujo de Admitir con la recogida seleccionada.',
        ),
      ),
    );
  }

  Future<String?> _manualGuideDialog({
    required String title,
    required String hint,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Buscar'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _RecogerHeader extends StatelessWidget {
  const _RecogerHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.black),
            tooltip: 'Atras',
          ),
          Image.asset(
            'assets/images/recoger/newrecogidas.png',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          const Text(
            'Recogidas',
            style: TextStyle(
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

class _RecogerTabs extends StatelessWidget {
  const _RecogerTabs({
    required this.selected,
    required this.disponibles,
    required this.reservadas,
    required this.efectivas,
    required this.onSelected,
  });

  final RecogerTab selected;
  final int disponibles;
  final int reservadas;
  final int efectivas;
  final ValueChanged<RecogerTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        children: [
          _RecogerTabItem(
            label: 'Disponibles',
            count: disponibles,
            selected: selected == RecogerTab.disponibles,
            onTap: () => onSelected(RecogerTab.disponibles),
          ),
          _RecogerTabItem(
            label: 'Reservadas',
            count: reservadas,
            selected: selected == RecogerTab.reservadas,
            onTap: () => onSelected(RecogerTab.reservadas),
          ),
          _RecogerTabItem(
            label: 'Efectivas',
            count: efectivas,
            selected: selected == RecogerTab.efectivas,
            onTap: () => onSelected(RecogerTab.efectivas),
          ),
        ],
      ),
    );
  }
}

class _RecogerTabItem extends StatelessWidget {
  const _RecogerTabItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.black : AppColors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.black),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? AppColors.white : AppColors.black,
                  fontFamily: 'Montserrat',
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

class _RecogidasList extends StatelessWidget {
  const _RecogidasList({
    required this.title,
    required this.counter,
    required this.items,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onOpenPreenvios,
    this.showSyncActions = false,
  });

  final String title;
  final int counter;
  final List<RecogidaItem> items;
  final String emptyMessage;
  final VoidCallback onRefresh;
  final ValueChanged<RecogidaItem> onOpenPreenvios;
  final bool showSyncActions;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 58, 0, 120),
            children: [
              if (items.isEmpty)
                _RecogerEmptyState(message: emptyMessage)
              else
                for (final item in items)
                  _RecogidaCard(
                    item: item,
                    showSyncActions: showSyncActions,
                    onTap: () => onOpenPreenvios(item),
                  ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: _SyncChip(
              title: title,
              count: counter,
              onTap: onRefresh,
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({
    required this.title,
    required this.count,
    required this.onTap,
  });

  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: AppColors.gray500,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh, color: AppColors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: AppColors.gray500,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecogidaCard extends StatelessWidget {
  const _RecogidaCard({
    required this.item,
    required this.showSyncActions,
    required this.onTap,
  });

  final RecogidaItem item;
  final bool showSyncActions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        shadowColor: AppColors.black.withValues(alpha: 0.12),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.04,
                    child: Image.asset(
                      'assets/images/recoger/detalle_recogida_bg.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.type,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    if (item.customerName.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.customerName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                    if (item.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Id - ${item.id}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.time,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
                if (showSyncActions)
                  const Positioned(
                    right: 2,
                    bottom: 2,
                    child: Column(
                      children: [
                        Icon(Icons.sync, color: AppColors.black),
                        SizedBox(height: 6),
                        Icon(Icons.share_outlined, color: AppColors.black),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecogerEmptyState extends StatelessWidget {
  const _RecogerEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 0),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.gray700,
          fontFamily: 'Montserrat',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PreenviosView extends StatelessWidget {
  const _PreenviosView({
    required this.searchController,
    required this.preenvios,
    required this.loading,
    required this.statusMessage,
    required this.errorMessage,
    required this.billingMessage,
    required this.onBack,
    required this.onSearch,
    required this.onScan,
    required this.onAddSale,
    required this.onBilling,
  });

  final TextEditingController searchController;
  final List<RecogidaPreenvio> preenvios;
  final bool loading;
  final String statusMessage;
  final String? errorMessage;
  final String billingMessage;
  final VoidCallback onBack;
  final ValueChanged<String> onSearch;
  final VoidCallback onScan;
  final VoidCallback onAddSale;
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) {
    final asociados = preenvios.length;
    final verificados = preenvios.where((item) => item.verified).length;
    final anulados = preenvios.where((item) => item.cancelled).length;
    final valor = preenvios.fold<double>(0, (sum, item) => sum + item.value);
    return ColoredBox(
      color: AppColors.white,
      child: Column(
        children: [
          _PreenviosHeader(onBack: onBack),
          _PreenviosCounters(
            asociados: asociados,
            verificados: verificados,
            anulados: anulados,
            valorCobrar: valor,
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          _RecogerStatusBanner(
            message: billingMessage.trim().isNotEmpty
                ? billingMessage
                : statusMessage,
            error: errorMessage,
          ),
          _PreenviosSearch(
            controller: searchController,
            onSearch: onSearch,
            onScan: onScan,
          ),
          Expanded(
            child: preenvios.isEmpty
                ? const _RecogerEmptyState(
                    message: 'No hay preenvios asociados a esta recogida.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: [
                      for (final item in preenvios) _PreenvioCard(item: item),
                    ],
                  ),
          ),
          _PreenviosActions(onAddSale: onAddSale, onBilling: onBilling),
        ],
      ),
    );
  }
}

class _PreenviosHeader extends StatelessWidget {
  const _PreenviosHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.black),
              tooltip: 'Atras',
            ),
          ),
          const Text(
            'Lista Preenvios',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreenviosCounters extends StatelessWidget {
  const _PreenviosCounters({
    required this.asociados,
    required this.verificados,
    required this.anulados,
    required this.valorCobrar,
  });

  final int asociados;
  final int verificados;
  final int anulados;
  final double valorCobrar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _PreenvioCounter(label: 'Asociados', value: '$asociados'),
          _PreenvioCounter(label: 'Verificados', value: '$verificados'),
          _PreenvioCounter(label: 'Anulados', value: '$anulados'),
          _PreenvioCounter(label: 'Valor cobrar', value: _money(valorCobrar)),
        ],
      ),
    );
  }
}

class _PreenvioCounter extends StatelessWidget {
  const _PreenvioCounter({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.black),
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreenviosSearch extends StatelessWidget {
  const _PreenviosSearch({
    required this.controller,
    required this.onSearch,
    required this.onScan,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.black),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => onSearch(controller.text),
                    icon: const Icon(Icons.search, color: AppColors.black),
                    tooltip: 'Buscar',
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Digite numero de guia',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.black),
            tooltip: 'Escanear',
          ),
        ],
      ),
    );
  }
}

class _PreenvioCard extends StatelessWidget {
  const _PreenvioCard({required this.item});

  final RecogidaPreenvio item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.guideNumber,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(item.sender),
            Text(item.recipient),
          ],
        ),
      ),
    );
  }
}

class _PreenviosActions extends StatelessWidget {
  const _PreenviosActions({
    required this.onAddSale,
    required this.onBilling,
  });

  final VoidCallback onAddSale;
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _PreenvioButton(
              label: 'Agregar nueva venta',
              icon: Icons.add,
              filled: false,
              onTap: onAddSale,
            ),
            const SizedBox(height: 8),
            _PreenvioButton(
              label: 'Facturar',
              icon: Icons.receipt_long,
              filled: true,
              onTap: onBilling,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreenvioButton extends StatelessWidget {
  const _PreenvioButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 350,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: filled ? AppColors.black : AppColors.white,
          foregroundColor: filled ? AppColors.white : AppColors.black,
          side: const BorderSide(color: AppColors.black),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _RecogerStatusBanner extends StatelessWidget {
  const _RecogerStatusBanner({required this.message, required this.error});

  final String message;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = error?.trim().isNotEmpty == true ? error!.trim() : message;
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final isError = error?.trim().isNotEmpty == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
          fontFamily: 'Montserrat',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AssignPickupSheet extends StatelessWidget {
  const _AssignPickupSheet({required this.pickup});

  final RecogidaItem pickup;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Reservar recogida',
                    style: TextStyle(
                      color: AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Id - ${pickup.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Montserrat'),
            ),
            const SizedBox(height: 6),
            Text(
              pickup.address,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Montserrat'),
            ),
            const SizedBox(height: 6),
            Text(
              pickup.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Montserrat'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _money(num value) {
  final text = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return '\$ ${buffer.toString()}';
}
