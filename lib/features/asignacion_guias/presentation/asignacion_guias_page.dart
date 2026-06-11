import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../models/asignacion_guias_models.dart';
import 'controllers/asignacion_guias_controller.dart';

const _background = Color(0xFFF3F3F3);
const _border = Color(0xFFE2E2E2);
const _field = Color(0xFFFDFDFD);
const _muted = Color(0xFF777777);

class AsignacionGuiasPage extends StatefulWidget {
  const AsignacionGuiasPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<AsignacionGuiasPage> createState() => _AsignacionGuiasPageState();
}

class _AsignacionGuiasPageState extends State<AsignacionGuiasPage> {
  late final AsignacionGuiasController _controller;
  final _messengerFocus = FocusNode();
  String? _lastShownMessage;
  bool _showMessengerList = false;

  @override
  void initState() {
    super.initState();
    _controller = AsignacionGuiasController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
    )..addListener(_handleControllerEvents);
    _messengerFocus.addListener(() {
      setState(() => _showMessengerList = _messengerFocus.hasFocus);
    });
    _controller.guideController.addListener(_refreshIcon);
    unawaited(_controller.initialize());
  }

  void _refreshIcon() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerEvents)
      ..dispose();
    _messengerFocus.dispose();
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

  Future<void> _openPreviousGuides() async {
    await _controller.loadPreviousGuides();
    if (!mounted || _controller.errorMessage != null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AsignacionGuiasPreviousPage(controller: _controller),
      ),
    );
  }

  Future<void> _confirmAssign() async {
    final selected = _controller.selectedMessenger;
    if (selected == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Confirmar asignación'),
        content: Text(
          '¿Estas seguro de asignar ${_controller.pendingGuides.length} guías a ${selected.nombre}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.assignGuides();
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
          'Asignación guías',
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
              Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                      child: _MainCard(
                        controller: _controller,
                        messengerFocus: _messengerFocus,
                        showMessengerList: _showMessengerList,
                        onShowMessengerList: () =>
                            setState(() => _showMessengerList = true),
                        onHideMessengerList: () {
                          _messengerFocus.unfocus();
                          setState(() => _showMessengerList = false);
                        },
                        onOpenPreviousGuides: _openPreviousGuides,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _controller.canAssign
                            ? _confirmAssign
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.black,
                          disabledBackgroundColor: AppColors.gray200,
                          foregroundColor: AppColors.white,
                          disabledForegroundColor: AppColors.gray500,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _controller.assigning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text(
                                'Asignar Envíos',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_controller.loading ||
                  _controller.loadingMessengers ||
                  _controller.loadingPrevious ||
                  _controller.reassigningPrevious)
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

class _MainCard extends StatelessWidget {
  const _MainCard({
    required this.controller,
    required this.messengerFocus,
    required this.showMessengerList,
    required this.onShowMessengerList,
    required this.onHideMessengerList,
    required this.onOpenPreviousGuides,
  });

  final AsignacionGuiasController controller;
  final FocusNode messengerFocus;
  final bool showMessengerList;
  final VoidCallback onShowMessengerList;
  final VoidCallback onHideMessengerList;
  final Future<void> Function() onOpenPreviousGuides;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedMessenger;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Seleccionar Mensajero',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 9),
            _MessengerSearch(
              controller: controller,
              focusNode: messengerFocus,
              showList: showMessengerList,
              onShowList: onShowMessengerList,
              onHideList: onHideMessengerList,
            ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              _GuideSearch(controller: controller),
              const SizedBox(height: 18),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_scanner, size: 42),
                      SizedBox(height: 8),
                      Text(
                        'Escanea la guía o digítala manualmente',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.pendingGuides.isEmpty
                          ? 'Guías'
                          : 'Guías (${controller.pendingGuides.length})',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.loadingPrevious
                        ? null
                        : onOpenPreviousGuides,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Guías Anteriores'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.black,
                      side: const BorderSide(color: AppColors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (controller.pendingGuides.isEmpty)
                const _EmptyState(
                  title: 'Sin guías agregadas',
                  body: 'Consulta una guía para armar el lote de asignación.',
                )
              else
                ...controller.pendingGuides.map(
                  (guide) => _PendingGuideTile(
                    guide: guide,
                    onDelete: () => controller.deletePendingGuide(guide),
                  ),
                ),
            ] else ...[
              const SizedBox(height: 26),
              const _EmptyState(
                title: 'Selecciona un apoyo',
                body:
                    'El buscador cargará los mensajeros activos disponibles para reasignar guías.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessengerSearch extends StatelessWidget {
  const _MessengerSearch({
    required this.controller,
    required this.focusNode,
    required this.showList,
    required this.onShowList,
    required this.onHideList,
  });

  final AsignacionGuiasController controller;
  final FocusNode focusNode;
  final bool showList;
  final VoidCallback onShowList;
  final VoidCallback onHideList;

  @override
  Widget build(BuildContext context) {
    final filtered = controller.filteredMessengers;
    final hasSelected = controller.selectedMessenger != null;
    return Column(
      children: [
        _FieldFrame(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.messengerController,
                  focusNode: focusNode,
                  onTap: onShowList,
                  onChanged: (_) {
                    controller.messengerTextChanged();
                    onShowList();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Seleccionar apoyo',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: hasSelected ? 'Cancelar' : 'Buscar',
                onPressed: hasSelected
                    ? () {
                        controller.clearMessenger();
                        onHideList();
                      }
                    : onShowList,
                icon: Icon(
                  hasSelected ? Icons.cancel_outlined : Icons.search,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),
        if (showList && !hasSelected)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: controller.loadingMessengers
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Consultando apoyos...'),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay apoyos disponibles.'),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: _border),
                        itemBuilder: (context, index) {
                          final messenger = filtered[index];
                          return ListTile(
                            dense: true,
                            onTap: () {
                              controller.selectMessenger(messenger);
                              onHideList();
                            },
                            title: Text(
                              messenger.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(messenger.identificacion),
                            trailing: const Icon(Icons.chevron_right),
                          );
                        },
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GuideSearch extends StatelessWidget {
  const _GuideSearch({required this.controller});

  final AsignacionGuiasController controller;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.guideController.text.trim().isNotEmpty;
    return _FieldFrame(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.guideController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => controller.scanOrSearchGuide(),
              decoration: const InputDecoration(
                hintText: 'Ingrese # guía',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: hasText ? 'Buscar guía' : 'Escanear guía',
            onPressed: controller.loading ? null : controller.scanOrSearchGuide,
            icon: Icon(
              hasText ? Icons.search : Icons.qr_code_scanner,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldFrame extends StatelessWidget {
  const _FieldFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Padding(padding: const EdgeInsets.only(left: 12), child: child),
    );
  }
}

class _PendingGuideTile extends StatelessWidget {
  const _PendingGuideTile({required this.guide, required this.onDelete});

  final AsignacionGuideState guide;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: guide.esReasignacionFallida
              ? const Color(0xFFFFF4F4)
              : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: guide.esReasignacionFallida ? AppColors.red : _border,
          ),
        ),
        child: ListTile(
          leading: const Icon(Icons.local_shipping_outlined),
          title: Text(
            guide.numeroGuia.toString(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            [
              if (guide.direccionDestinatario.trim().isNotEmpty)
                guide.direccionDestinatario.trim(),
              'Peso: ${guide.peso}',
              'Estado: ${guide.estadoGuia}',
            ].join(' · '),
          ),
          trailing: IconButton(
            tooltip: 'Eliminar guía',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.red),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.assignment_late_outlined, size: 34),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class AsignacionGuiasPreviousPage extends StatelessWidget {
  const AsignacionGuiasPreviousPage({super.key, required this.controller});

  final AsignacionGuiasController controller;

  Future<void> _showBulkReassignDialog(BuildContext context) async {
    final current = controller.selectedMessenger;
    final targets = [
      AsignacionMessenger.parent(
        idMensajero: int.tryParse(controller.appInformation.idMensajero) ?? 0,
        idTipoMensajero:
            int.tryParse(controller.appInformation.idTipoMensajero) ?? 0,
        nombre: 'Asignar al principal',
      ),
      ...controller.messengers.where(
        (item) => item.idMensajero != current?.idMensajero,
      ),
    ];
    if (targets.isEmpty) return;
    var selected = targets.first;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Text('Reasignar planillas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Planilla de ${controller.previousSheets.expand((item) => item.guias).where((guide) => guide.isPlanillada).length} guías',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AsignacionMessenger>(
                initialValue: selected,
                items: targets
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.nombre),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selected = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Seleccionar Mensajero',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.reassignPreviousPlanilladas(selected);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Reasignar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messenger = controller.selectedMessenger;
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
          'Guías Anteriores',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: controller.reassigningPrevious
                          ? null
                          : () => _showBulkReassignDialog(context),
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: const Text('Reasignar planillas'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.black,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Total guías: ${controller.totalPreviousGuides}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (messenger != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        messenger.nombre,
                        style: const TextStyle(color: _muted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (controller.previousSheets.isEmpty)
                      const _EmptyState(
                        title: 'Sin guías anteriores',
                        body: 'No se encontraron planillas para este apoyo.',
                      )
                    else
                      ...controller.previousSheets.asMap().entries.map(
                        (entry) => _PreviousSheetTile(
                          sheetIndex: entry.key,
                          sheet: entry.value,
                          controller: controller,
                        ),
                      ),
                  ],
                ),
              ),
              if (controller.reassigningPrevious || controller.loadingPrevious)
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

class _PreviousSheetTile extends StatelessWidget {
  const _PreviousSheetTile({
    required this.sheetIndex,
    required this.sheet,
    required this.controller,
  });

  final int sheetIndex;
  final AssignedSheet sheet;
  final AsignacionGuiasController controller;

  @override
  Widget build(BuildContext context) {
    final canReassignSheet = sheet.guias.any((guide) => guide.isPlanillada);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              'Planilla de ${sheet.guias.length} guías',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              [
                'Planilla ${sheet.idPlanilla}',
                if (sheet.fechaAsignacion.trim().isNotEmpty)
                  sheet.fechaAsignacion,
              ].join(' · '),
            ),
            trailing: IconButton(
              tooltip: 'Desasignar planilla',
              onPressed: canReassignSheet
                  ? () => controller.reassignSheetToParent(sheetIndex)
                  : null,
              icon: const Icon(Icons.assignment_return_outlined),
            ),
            children: sheet.guias.asMap().entries.map((entry) {
              return _PreviousGuideTile(
                sheetIndex: sheetIndex,
                guideIndex: entry.key,
                guide: entry.value,
                controller: controller,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _PreviousGuideTile extends StatelessWidget {
  const _PreviousGuideTile({
    required this.sheetIndex,
    required this.guideIndex,
    required this.guide,
    required this.controller,
  });

  final int sheetIndex;
  final int guideIndex;
  final PreviousGuide guide;
  final AsignacionGuiasController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        guide.isPlanillada ? Icons.local_shipping_outlined : Icons.info_outline,
      ),
      title: Text(
        guide.numeroGuia.toString(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        [
          if (guide.direccionDestinatario.trim().isNotEmpty)
            guide.direccionDestinatario.trim(),
          'Estado: ${guide.estado}',
          'Valor: ${guide.valorTotal}',
          if (guide.esReasignacionFallida) 'No reasignada',
        ].join(' · '),
      ),
      trailing: IconButton(
        tooltip: 'Desasignar guía',
        onPressed: guide.isPlanillada
            ? () => controller.reassignGuideToParent(
                sheetIndex: sheetIndex,
                guideIndex: guideIndex,
              )
            : null,
        icon: const Icon(Icons.undo_outlined),
      ),
    );
  }
}
