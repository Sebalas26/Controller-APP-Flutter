import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../shared/native/controller_native_bridge.dart';
import '../../../shared/network/controller_api_config.dart';
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
  _EntregaModule _selectedModule = _EntregaModule.enZona;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntregasStatus(controller: _controller),
        const SizedBox(height: 12),
        _EntregasBanner(controller: _controller),
        const SizedBox(height: 12),
        _moduleSelector(),
        const SizedBox(height: 12),
        if (_controller.loading)
          const _EntregasPanel(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          _EntregasPanel(child: _body()),
      ],
    );
  }

  Widget _moduleSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_EntregaModule>(
        selected: {_selectedModule},
        onSelectionChanged: (value) {
          setState(() => _selectedModule = value.first);
          switch (value.first) {
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
        segments: const [
          ButtonSegment(
            value: _EntregaModule.enZona,
            icon: Icon(Icons.location_on_outlined),
            label: Text('En zona'),
          ),
          ButtonSegment(
            value: _EntregaModule.entregadas,
            icon: Icon(Icons.check_circle_outline),
            label: Text('Entregadas'),
          ),
          ButtonSegment(
            value: _EntregaModule.devolucion,
            icon: Icon(Icons.assignment_return_outlined),
            label: Text('Devolucion'),
          ),
          ButtonSegment(
            value: _EntregaModule.buscar,
            icon: Icon(Icons.qr_code_scanner),
            label: Text('Buscar'),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_selectedModule) {
      case _EntregaModule.enZona:
        return _moduleBody(
          title: 'Guias en zona',
          guides: _controller.inZone,
          emptyIcon: Icons.location_off_outlined,
          onRefresh: _controller.refreshInZone,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _controller.loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
                FilledButton.icon(
                  onPressed: _controller.syncing
                      ? null
                      : () => _run(_controller.syncPending),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar'),
                ),
              ],
            ),
          ],
        ),
        if (trailing != null) ...[const SizedBox(height: 12), trailing],
        const SizedBox(height: 12),
        if (guides.isEmpty)
          _EntregasEmptyState(
            icon: emptyIcon,
            title: 'Sin guias',
            message: 'No hay registros para este modulo.',
          )
        else
          ...guides.map((guide) => _guideCard(guide)),
      ],
    );
  }

  Widget _searchPanel() {
    final searched = _controller.searchedGuide;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Buscar guia',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _runSearch(_searchController.text),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _openQrDialog,
                  tooltip: 'QR',
                  icon: const Icon(Icons.qr_code_scanner),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _runSearch(_searchController.text),
                  tooltip: 'Consultar',
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
            if (searched != null) ...[
              const SizedBox(height: 12),
              _GuideSummary(
                guide: searched,
                onDeliver: () =>
                    _openDelivery(searched, isQr: _lastSearchWasQr),
                onReturn: () => _openReturn(searched, isQr: _lastSearchWasQr),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _guideCard(EntregaGuide guide) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GuideSummary(
        guide: guide,
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

class _EntregasStatus extends StatelessWidget {
  const _EntregasStatus({required this.controller});

  final EntregasController controller;

  @override
  Widget build(BuildContext context) {
    return _EntregasPanel(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatusChip(
            icon: controller.offline ? Icons.wifi_off : Icons.wifi,
            label: controller.offline ? 'Offline' : 'Online',
          ),
          _StatusChip(
            icon: Icons.local_shipping_outlined,
            label: 'En zona ${controller.inZone.length}',
          ),
          _StatusChip(
            icon: Icons.check_circle_outline,
            label: 'Entregadas ${controller.delivered.length}',
          ),
          _StatusChip(
            icon: Icons.assignment_return_outlined,
            label: 'Devolucion ${controller.returned.length}',
          ),
          _StatusChip(
            icon: Icons.pending_actions_outlined,
            label: 'Pendientes ${controller.pendingSyncCount}',
          ),
        ],
      ),
    );
  }
}

class _EntregasBanner extends StatelessWidget {
  const _EntregasBanner({required this.controller});

  final EntregasController controller;

  @override
  Widget build(BuildContext context) {
    final text = controller.errorMessage ?? controller.statusMessage;
    if (text.trim().isEmpty && !controller.syncing) {
      return const SizedBox.shrink();
    }
    final error = controller.errorMessage != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (controller.syncing) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ] else
              Icon(error ? Icons.error_outline : Icons.info_outline),
            if (!controller.syncing) const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _GuideSummary extends StatelessWidget {
  const _GuideSummary({required this.guide, this.onDeliver, this.onReturn});

  final EntregaGuide guide;
  final VoidCallback? onDeliver;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    guide.guideNumber,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(
                  label: Text(guide.displayState),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoLine(Icons.person_outline, guide.recipientName),
            _InfoLine(Icons.location_on_outlined, guide.recipientAddress),
            _InfoLine(Icons.phone_outlined, guide.phone),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniPill('Planilla', guide.planSheet.toString()),
                _MiniPill('Ciudad', guide.city),
                _MiniPill('Cobro', '\$${guide.valueToCollect}'),
              ],
            ),
            if (onDeliver != null || onReturn != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDeliver,
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Entregar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReturn,
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: const Text('Devolver'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
      title: 'Entregar ${widget.guide.guideNumber}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre recibe',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _documentController,
            decoration: const InputDecoration(
              labelText: 'Identificacion',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Telefono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _observationController,
            decoration: const InputDecoration(
              labelText: 'Observaciones',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
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
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando' : 'Guardar entrega'),
          ),
        ],
      ),
    );
  }

  Widget _photoCapture() {
    final bytes = _photoBytes();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
            OutlinedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.photo_camera),
              label: Text(bytes == null ? 'Tomar foto' : 'Repetir foto'),
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
      title: 'Devolver ${widget.guide.guideNumber}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<EntregaReason>(
            initialValue: _reason,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              prefixIcon: Icon(Icons.assignment_return_outlined),
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
          TextField(
            controller: _observationController,
            decoration: const InputDecoration(
              labelText: 'Observaciones',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando' : 'Guardar devolucion'),
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
            color: Colors.white,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
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
  const _SheetScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _EntregasPanel extends StatelessWidget {
  const _EntregasPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.value);

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text('$label: ${value.trim().isEmpty ? '-' : value}'),
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
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
