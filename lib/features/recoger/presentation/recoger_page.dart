import 'package:flutter/material.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../models/recoger_models.dart';

enum _RecogerTab { disponibles, reservadas, efectivas }

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
  _RecogerTab _selectedTab = _RecogerTab.disponibles;
  bool _showPreenvios = false;
  final _searchController = TextEditingController();

  final _disponibles = const <RecogidaItem>[];
  final _reservadas = const <RecogidaItem>[
    RecogidaItem(
      id: 'Id - Recogida',
      type: 'TIPO RECOGIDA',
      address: 'Cra 44 # 3 - 87 Bodega dos segunda puerta',
      customerName: 'Nombres Completos',
      description: '# Envios - Peso kg',
      time: '12:00',
    ),
  ];
  final _efectivas = const <RecogidaItem>[];
  final _preenvios = const <RecogidaPreenvio>[];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showPreenvios) {
      return _PreenviosView(
        searchController: _searchController,
        preenvios: _preenvios,
        onBack: () => setState(() => _showPreenvios = false),
      );
    }
    return ColoredBox(
      color: AppColors.white,
      child: Column(
        children: [
          _RecogerHeader(onBack: () => Navigator.of(context).maybePop()),
          _RecogerTabs(
            selected: _selectedTab,
            disponibles: _disponibles.length,
            reservadas: _reservadas.length,
            efectivas: _efectivas.length,
            onSelected: (tab) => setState(() => _selectedTab = tab),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_selectedTab) {
      case _RecogerTab.disponibles:
        return _RecogidasList(
          title: 'Recogidas disponibles',
          counter: _disponibles.length,
          items: _disponibles,
          emptyMessage: 'No hay recogidas disponibles para mostrar.',
          onRefresh: () {},
          onOpenPreenvios: () => setState(() => _showPreenvios = true),
        );
      case _RecogerTab.reservadas:
        return _RecogidasList(
          title: 'Recogidas reservadas',
          counter: _reservadas.length,
          items: _reservadas,
          emptyMessage: 'No hay recogidas reservadas para mostrar.',
          onRefresh: () {},
          onOpenPreenvios: () => setState(() => _showPreenvios = true),
        );
      case _RecogerTab.efectivas:
        return _RecogidasList(
          title: 'Recogidas efectivas',
          counter: _efectivas.length,
          items: _efectivas,
          emptyMessage: 'No hay recogidas efectivas para mostrar.',
          showSyncActions: true,
          onRefresh: () {},
          onOpenPreenvios: () => setState(() => _showPreenvios = true),
        );
    }
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

  final _RecogerTab selected;
  final int disponibles;
  final int reservadas;
  final int efectivas;
  final ValueChanged<_RecogerTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        children: [
          _RecogerTabItem(
            label: 'Disponibles',
            count: disponibles,
            selected: selected == _RecogerTab.disponibles,
            onTap: () => onSelected(_RecogerTab.disponibles),
          ),
          _RecogerTabItem(
            label: 'Reservadas',
            count: reservadas,
            selected: selected == _RecogerTab.reservadas,
            onTap: () => onSelected(_RecogerTab.reservadas),
          ),
          _RecogerTabItem(
            label: 'Efectivas',
            count: efectivas,
            selected: selected == _RecogerTab.efectivas,
            onTap: () => onSelected(_RecogerTab.efectivas),
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
  final VoidCallback onOpenPreenvios;
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
                    onTap: onOpenPreenvios,
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
                      item.id,
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
    required this.onBack,
  });

  final TextEditingController searchController;
  final List<RecogidaPreenvio> preenvios;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final asociados = preenvios.length;
    final verificados = preenvios.where((item) => item.verified).length;
    final anulados = preenvios.where((item) => item.cancelled).length;
    final valor = preenvios.fold<int>(0, (sum, item) => sum + item.value);
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
          _PreenviosSearch(controller: searchController),
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
          const _PreenviosActions(),
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
  final int valorCobrar;

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
  const _PreenviosSearch({required this.controller});

  final TextEditingController controller;

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
                    onPressed: () {},
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
            onPressed: () {},
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
  const _PreenviosActions();

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
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _PreenvioButton(
              label: 'Facturar',
              icon: Icons.receipt_long,
              filled: true,
              onTap: () {},
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

String _money(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return '\$ ${buffer.toString()}';
}
