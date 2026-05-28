import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../models/bloques_models.dart';
import 'controllers/bloques_flow_controller.dart';
import 'views/bloques_courier_details_view.dart';
import 'views/bloques_deliveries_view.dart';
import 'views/bloques_qr_scanner_view.dart';
import 'widgets/bloques_widgets.dart';

class BloquesPage extends StatefulWidget {
  const BloquesPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<BloquesPage> createState() => _BloquesPageState();
}

class _BloquesPageState extends State<BloquesPage> {
  late final BloquesFlowController _controller;
  bool _showManaged = false;
  bool _syncing = false;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _controller = BloquesFlowController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
    )..addListener(_onControllerChanged);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (mounted) {
      setState(() => _lastUpdate = DateTime.now());
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visibleBlocks = _visibleBlocks;
    return ColoredBox(
      color: AppColors.white,
      child: Stack(
        children: [
          Column(
            children: [
              BloquesTopBar(
                title: _showManaged
                    ? 'Bloques gestionados'
                    : 'Gestion de entregas',
                onBack: () => Navigator.of(context).maybePop(),
                filterActive: _showManaged,
                showFilter: true,
                onFilter: () => setState(() => _showManaged = !_showManaged),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _controller.loading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildContent(visibleBlocks),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 8,
                      child: BloquesStatusBanner(controller: _controller),
                    ),
                  ],
                ),
              ),
              BloquesBottomActionBar(
                busy: _controller.busyRemote,
                onManage: _showMethodSheet,
              ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 90 + MediaQuery.paddingOf(context).bottom,
            child: BloquesSyncFab(syncing: _syncing, onPressed: _syncBlocks),
          ),
        ],
      ),
    );
  }

  List<YaapPendingBlock> get _visibleBlocks {
    return _controller.pendingBlocks
        .where((block) {
          final closed = _isClosedBlock(block);
          return _showManaged ? closed : !closed;
        })
        .toList(growable: false);
  }

  Widget _buildContent(List<YaapPendingBlock> blocks) {
    if (blocks.isEmpty) return const BloquesCentralMessage();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 72, 0, 96),
      itemCount: blocks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return BloquesListHeader(
            title: _showManaged
                ? 'Bloques gestionados'
                : 'Pendientes por gestionar',
            lastUpdateLabel: _lastUpdateLabel,
          );
        }
        final block = blocks[index - 1];
        return BloquesPendingBlockCard(
          block: block,
          busy: _controller.busyRemote,
          onTap: () => _openBlock(block),
        );
      },
    );
  }

  String get _lastUpdateLabel {
    final value = _lastUpdate;
    if (value == null) return 'Ultima actualizacion pendiente';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return 'Ultima actualizacion: $hour:$minute';
  }

  Future<bool> _runAction(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Future<void> _syncBlocks() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final startedAt = DateTime.now();
    final success = await _runAction(() => _controller.refreshPendingBlocks());
    if (success && mounted) {
      setState(() => _lastUpdate = DateTime.now());
    }
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = const Duration(seconds: 10) - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (mounted) setState(() => _syncing = false);
  }

  void _showMethodSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BloquesMethodSheet(
          onClose: () => Navigator.of(sheetContext).pop(),
          onQr: () {
            Navigator.of(sheetContext).pop();
            unawaited(_scanAndValidate());
          },
          onCode: () {
            Navigator.of(sheetContext).pop();
            _showCodeSheet();
          },
        );
      },
    );
  }

  void _showCodeSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BloquesCodeSheet(
          onClose: () => Navigator.of(sheetContext).pop(),
          onQr: () {
            Navigator.of(sheetContext).pop();
            unawaited(_scanAndValidate());
          },
          onValidate: (document, code) async {
            final valid = await _identifyCourier(document, code);
            if (valid && sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
              _openCourierDetails();
            }
            return valid;
          },
        );
      },
    );
  }

  Future<void> _scanAndValidate() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BloquesQrScannerView()),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;
    try {
      final identity = await _controller.identityFromQr(raw);
      await _identifyAndOpenDetails(identity.document, identity.otp);
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

  Future<bool> _identifyAndOpenDetails(String document, String code) async {
    final valid = await _identifyCourier(document, code);
    if (!valid || !mounted) return false;
    _openCourierDetails();
    return true;
  }

  Future<bool> _identifyCourier(String document, String code) async {
    return _runAction(() => _controller.identifyCourier(document, code));
  }

  Future<void> _openBlock(YaapPendingBlock block) async {
    final valid = await _runAction(() async {
      await _controller.validateBlockManagement(block);
      _controller.openPendingBlock(block);
    });
    if (valid && mounted) _openDeliveries();
  }

  void _openCourierDetails() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BloquesCourierDetailsPage(
          controller: _controller,
          runAction: _runAction,
        ),
      ),
    );
  }

  void _openDeliveries() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BloquesDeliveriesPage(
          controller: _controller,
          runAction: _runAction,
        ),
      ),
    );
  }
}

class _BloquesCourierDetailsPage extends StatelessWidget {
  const _BloquesCourierDetailsPage({
    required this.controller,
    required this.runAction,
  });

  final BloquesFlowController controller;
  final Future<bool> Function(Future<void> Function() action) runAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: const Text('Datos domiciliario')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Stack(
            children: [
              BloquesCourierDetailsView(
                controller: controller,
                onContinue: () => unawaited(_continueToDeliveries(context)),
                onReject: () => unawaited(_showRejectSheet(context)),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 8,
                child: BloquesStatusBanner(controller: controller),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _continueToDeliveries(BuildContext context) async {
    final prepared = await runAction(controller.prepareCourierForDeliveries);
    if (!prepared || !context.mounted) return;
    final loaded = await runAction(controller.loadDeliveryManagement);
    if (!loaded || !context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _BloquesDeliveriesPage(
          controller: controller,
          runAction: runAction,
        ),
      ),
    );
  }

  Future<void> _showRejectSheet(BuildContext context) async {
    final rejected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BloquesRejectCourierSheet(
        controller: controller,
        runAction: runAction,
      ),
    );
    if ((rejected ?? false) && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _BloquesDeliveriesPage extends StatelessWidget {
  const _BloquesDeliveriesPage({
    required this.controller,
    required this.runAction,
  });

  final BloquesFlowController controller;
  final Future<bool> Function(Future<void> Function() action) runAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: const Text('Gestion de entregas')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Stack(
            children: [
              BloquesDeliveriesView(
                controller: controller,
                runAction: (action) async {
                  await runAction(action);
                },
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 8,
                child: BloquesStatusBanner(controller: controller),
              ),
            ],
          );
        },
      ),
    );
  }
}

bool _isClosedBlock(YaapPendingBlock block) {
  if (block.endsAt != null) return true;
  final status = block.status.toLowerCase();
  return status.contains('cerrado') ||
      status.contains('closed') ||
      status.contains('gestionado');
}
