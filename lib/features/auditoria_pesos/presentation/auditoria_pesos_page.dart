import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/network/controller_api_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../login/login.dart';
import '../models/auditoria_pesos_models.dart';
import 'controllers/auditoria_pesos_controller.dart';

const _surface = Color(0xFFFEFEFE);
const _border = Color(0xFFE0E0E0);
const _muted = Color(0xFF727272);
const _blue = Color(0xFF2569B3);
const _orange = Color(0xFFF58220);
const _softPurple = Color(0xFFF0EDFB);
const _purple = Color(0xFF6E52E1);

class AuditoriaPesosPage extends StatefulWidget {
  const AuditoriaPesosPage({
    super.key,
    required this.appInformation,
    required this.apiConfig,
    required this.offline,
  });

  final AppInformation appInformation;
  final ControllerApiConfig apiConfig;
  final bool offline;

  @override
  State<AuditoriaPesosPage> createState() => _AuditoriaPesosPageState();
}

class _AuditoriaPesosPageState extends State<AuditoriaPesosPage> {
  late final AuditoriaPesosController _controller;
  String? _lastShownMessage;

  @override
  void initState() {
    super.initState();
    _controller = AuditoriaPesosController(
      appInformation: widget.appInformation,
      apiConfig: widget.apiConfig,
      offline: widget.offline,
    )..addListener(_showControllerMessages);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_showControllerMessages)
      ..dispose();
    super.dispose();
  }

  void _showControllerMessages() {
    final message = _controller.errorMessage ?? _controller.statusMessage;
    if (!mounted || message == null || message == _lastShownMessage) return;
    _lastShownMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isError = _controller.errorMessage == message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFF01623D),
          duration: Duration(seconds: isError ? 5 : 4),
        ),
      );
    });
  }

  Future<void> _leave() async {
    if (!_controller.hasGuide) {
      Navigator.of(context).maybePop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir de auditoría'),
        content: const Text(
          'Tienes un proceso de auditoría de pesos en curso. ¿Deseas salir?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        elevation: 0,
        leading: IconButton(
          onPressed: _leave,
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          tooltip: 'Atras',
        ),
        title: const Text(
          'Auditoría pesos',
          style: TextStyle(
            color: _blue,
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AuditTabs(controller: _controller),
                    const SizedBox(height: 18),
                    if (_controller.selectedTab == AuditoriaPesosTab.auditoria)
                      _AuditFlow(controller: _controller)
                    else
                      _ReportsFlow(controller: _controller),
                  ],
                ),
              ),
              if (_controller.loading ||
                  _controller.saving ||
                  _controller.takingPhoto ||
                  _controller.reportLoading ||
                  _controller.reportDownloading)
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

class _AuditTabs extends StatelessWidget {
  const _AuditTabs({required this.controller});

  final AuditoriaPesosController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Auditoría',
              selected: controller.selectedTab == AuditoriaPesosTab.auditoria,
              onTap: () => controller.selectTab(AuditoriaPesosTab.auditoria),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TabButton(
              label: 'Reportes',
              selected: controller.selectedTab == AuditoriaPesosTab.reportes,
              onTap: () => controller.selectTab(AuditoriaPesosTab.reportes),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: selected ? AppColors.black : const Color(0xFFEDEDED),
        foregroundColor: selected ? AppColors.white : AppColors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }
}

class _AuditFlow extends StatelessWidget {
  const _AuditFlow({required this.controller});

  final AuditoriaPesosController controller;

  @override
  Widget build(BuildContext context) {
    final guide = controller.guide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchGuide(controller: controller),
        if (guide != null) ...[
          const SizedBox(height: 18),
          _SystemInfoCard(guide: guide),
          const SizedBox(height: 16),
          _WeightModeSelector(controller: controller),
          const SizedBox(height: 18),
          _PhotosSection(controller: controller),
          const SizedBox(height: 18),
          _NewWeightSection(controller: controller),
          const SizedBox(height: 18),
          _AuditTextField(
            label: 'Observaciones',
            controller: controller.observacionesController,
            hint: 'Escriba las novedades',
            maxLines: 3,
            maxLength: 100,
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: controller.canSave
                ? () => _confirmSave(context, controller)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              disabledBackgroundColor: AppColors.gray200,
              foregroundColor: AppColors.white,
              disabledForegroundColor: _muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(controller.saving ? 'Guardando...' : 'Guardar'),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmSave(
    BuildContext context,
    AuditoriaPesosController controller,
  ) async {
    final validation = controller.validationMessage();
    if (validation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation), backgroundColor: Colors.red),
      );
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agradecemos su gestión'),
        content: Text(
          'El sistema identifica una diferencia de: ${controller.differenceWeight} Kg.\n\n'
          'Esta información será verificada por un grupo de auditores para reliquidación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (save == true) await controller.saveAudit();
  }
}

class _SearchGuide extends StatelessWidget {
  const _SearchGuide({required this.controller});

  final AuditoriaPesosController controller;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.guiaController.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _blue, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.guiaController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(14),
              ],
              style: const TextStyle(
                color: _blue,
                fontFamily: 'Montserrat',
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Buscar guía',
                hintStyle: TextStyle(color: _muted),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => controller.consultGuide(),
              onChanged: (_) => controller.guideInputChanged(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SizedBox(
              width: 48,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: controller.loading
                      ? null
                      : controller.consultGuide,
                  icon: Icon(
                    hasText ? Icons.search : Icons.qr_code_scanner,
                    color: AppColors.white,
                  ),
                  tooltip: hasText ? 'Buscar' : 'Escanear',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemInfoCard extends StatelessWidget {
  const _SystemInfoCard({required this.guide});

  final AuditoriaGuide guide;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.info_outline,
            title: 'Información sistema',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 14,
            children: [
              _InfoValue(
                label: 'Peso total',
                value: '${_weight(guide.pesoAuditableSistema)} Kg',
              ),
              _InfoValue(
                label: 'Valor comercial',
                value: _currency(guide.valorComercialSistema),
              ),
              _InfoValue(
                label: 'Valor total',
                value: _currency(guide.valorTotalSistema),
              ),
              _InfoValue(
                label: 'Origen',
                value: guide.nombreCiudadOrigenSistema,
              ),
              _InfoValue(
                label: 'Destino',
                value: guide.nombreCiudadDestinoSistema,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightModeSelector extends StatelessWidget {
  const _WeightModeSelector({required this.controller});

  final AuditoriaPesosController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ModeRow(
          label: 'Peso báscula',
          selected: controller.weightMode == AuditoriaWeightMode.bascula,
          onTap: () => _selectMode(context, AuditoriaWeightMode.bascula),
        ),
        const SizedBox(height: 10),
        _ModeRow(
          label: 'Peso volumétrico',
          selected: controller.weightMode == AuditoriaWeightMode.volumetrico,
          onTap: () => _selectMode(context, AuditoriaWeightMode.volumetrico),
        ),
      ],
    );
  }

  Future<void> _selectMode(
    BuildContext context,
    AuditoriaWeightMode mode,
  ) async {
    if (controller.weightMode == mode) return;
    if (!controller.hasPhotos) {
      controller.setWeightMode(mode);
      return;
    }
    final change = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar tipo de peso'),
        content: const Text(
          'Al cambiar el tipo de auditoría se limpiarán las fotos y el nuevo peso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (change == true) controller.setWeightMode(mode);
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _blue,
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 60,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: selected ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: selected ? _blue : const Color(0xFFEDEDED),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: selected ? AppColors.white : _blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({required this.controller});

  final AuditoriaPesosController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: controller.takingPhoto
              ? null
              : controller.captureMissingPhotos,
          style: FilledButton.styleFrom(
            backgroundColor: _orange,
            disabledBackgroundColor: AppColors.gray200,
            foregroundColor: AppColors.white,
            disabledForegroundColor: _muted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text('Agregar fotos (${controller.photos.length})'),
        ),
        const SizedBox(height: 16),
        const _SectionHeading(
          icon: Icons.collections_outlined,
          title: 'Fotos del envío',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _PhotoTile(
                photo: controller.photos[index],
                onTap: () => controller.takePhotoAt(index),
                onRemove: controller.photos[index].hasImage
                    ? () => controller.removePhotoAt(index)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.onTap,
    required this.onRemove,
  });

  final AuditoriaPhoto photo;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: photo.hasImage ? _blue : _border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(child: _PhotoContent(photo: photo)),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  photo.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: photo.hasImage ? AppColors.white : AppColors.black,
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    shadows: photo.hasImage
                        ? const [Shadow(color: AppColors.black, blurRadius: 5)]
                        : null,
                  ),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: const CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.black,
                      child: Icon(
                        Icons.close,
                        color: AppColors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoContent extends StatelessWidget {
  const _PhotoContent({required this.photo});

  final AuditoriaPhoto photo;

  @override
  Widget build(BuildContext context) {
    if (photo.hasImage) {
      try {
        return Image.memory(
          base64Decode(photo.base64File),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      } on Object {
        return const ColoredBox(color: _softPurple);
      }
    }
    return const Center(
      child: Icon(Icons.add_a_photo_outlined, color: _muted, size: 30),
    );
  }
}

class _NewWeightSection extends StatelessWidget {
  const _NewWeightSection({required this.controller});

  final AuditoriaPesosController controller;

  @override
  Widget build(BuildContext context) {
    final isVolumetric =
        controller.weightMode == AuditoriaWeightMode.volumetrico;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(icon: Icons.monitor_weight, title: 'Nuevo peso'),
        const SizedBox(height: 12),
        if (isVolumetric)
          _VolumetricWeightInputs(controller: controller)
        else
          SizedBox(
            width: 160,
            child: _AuditTextField(
              label: 'Peso báscula',
              controller: controller.pesoBasculaController,
              hint: 'Kg',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
            ),
          ),
        if (controller.differenceWeight > 0) ...[
          const SizedBox(height: 12),
          _DifferenceChip(value: controller.differenceWeight),
        ],
      ],
    );
  }
}

class _VolumetricWeightInputs extends StatelessWidget {
  const _VolumetricWeightInputs({required this.controller});

  final AuditoriaPesosController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MeasureInput(
                label: 'Largo',
                controller: controller.largoController,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MeasureInput(
                label: 'Ancho',
                controller: controller.anchoController,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MeasureInput(
                label: 'Alto',
                controller: controller.altoController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Peso Volumétrico',
          style: TextStyle(
            color: _muted,
            fontFamily: 'Montserrat',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 144,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _softPurple,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _purple),
          ),
          child: Text(
            controller.volumetricWeight > 0
                ? '${controller.volumetricWeight}Kg'
                : '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _purple,
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MeasureInput extends StatelessWidget {
  const _MeasureInput({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _AuditTextField(
      label: label,
      controller: controller,
      hint: 'cm',
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
    );
  }
}

class _ReportsFlow extends StatelessWidget {
  const _ReportsFlow({required this.controller});

  final AuditoriaPesosController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.reportSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateSelector(
          label: 'Fecha Inicial',
          value: controller.reportStartDate,
          onTap: () => _pickDate(context, true),
        ),
        const SizedBox(height: 14),
        _DateSelector(
          label: 'Fecha Final',
          value: controller.reportEndDate,
          onTap: () => _pickDate(context, false),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: controller.reportLoading ? null : controller.consultReport,
          style: _primaryButtonStyle(),
          child: Text(
            controller.reportLoading ? 'Consultando...' : 'Consultar',
          ),
        ),
        if (summary != null) ...[
          const SizedBox(height: 20),
          _ReportSummary(summary: summary),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.reportDownloading
                ? null
                : controller.downloadDetailedReport,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.black,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.download_outlined),
            label: Text(
              controller.reportDownloading
                  ? 'Descargando...'
                  : 'Descargar informe',
            ),
          ),
        ],
        if (controller.reportDetails.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _SectionHeading(
            icon: Icons.list_alt_outlined,
            title: 'Detalle descargado',
          ),
          const SizedBox(height: 10),
          ...controller.reportDetails.take(8).map(_ReportDetailTile.new),
        ],
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, bool start) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month - 1, 1);
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: firstDate,
      lastDate: now,
    );
    if (selected == null) return;
    if (start) {
      controller.setReportStartDate(selected);
    } else {
      controller.setReportEndDate(selected);
    }
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.summary});

  final AuditoriaReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricRow(
          icon: Icons.fact_check_outlined,
          label: 'Cantidad de auditorías',
          value: summary.cantidadAuditorias.toString(),
        ),
        _MetricRow(
          icon: Icons.check_circle_outline,
          label: 'Auditorías aprobadas',
          value: summary.cantidadAprobadas.toString(),
        ),
        _MetricRow(
          icon: Icons.cancel_outlined,
          label: 'Auditorías rechazadas',
          value: summary.cantidadRechazadas.toString(),
        ),
        _MetricRow(
          icon: Icons.hourglass_bottom_outlined,
          label: 'Auditorías por aprobar',
          value: summary.cantidadPorAprobar.toString(),
        ),
        _MetricRow(
          icon: Icons.warning_amber_outlined,
          label: 'Reliquidaciones que no aplican',
          value: summary.cantidadNoAplican.toString(),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            children: [
              _AmountLine(
                label: 'Valor total',
                value: _currency(summary.totalComision),
              ),
              const SizedBox(height: 8),
              _AmountLine(
                label: 'Valor de la ganancia',
                value: _currency(summary.totalGanancia),
              ),
              const SizedBox(height: 12),
              const _Notice(
                text:
                    'Esta comisión está sujeta a la aprobación de la auditoría.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportDetailTile extends StatelessWidget {
  const _ReportDetailTile(this.detail);

  final AuditoriaReportDetail detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Panel(
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: _blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.numeroGuia,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${detail.estadoAuditoria} · ${detail.fechaAuditoria}',
                    style: const TextStyle(
                      color: _muted,
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _currency(detail.valorComision),
              style: const TextStyle(
                color: _blue,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Panel(
        child: Row(
          children: [
            Icon(icon, color: _blue, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.black,
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.trim().isEmpty ? 'Seleccione' : value,
                    style: TextStyle(
                      color: value.trim().isEmpty ? _muted : AppColors.black,
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditTextField extends StatelessWidget {
  const _AuditTextField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontFamily: 'Montserrat',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 14,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: const TextStyle(color: _muted),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
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
              borderSide: const BorderSide(color: _blue, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.black, size: 18),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoValue extends StatelessWidget {
  const _InfoValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '-' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _blue,
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifferenceChip extends StatelessWidget {
  const _DifferenceChip({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _softPurple,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _purple),
      ),
      child: Text(
        'Diferencia identificada: $value Kg',
        style: const TextStyle(
          color: _purple,
          fontFamily: 'Montserrat',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label:',
            style: const TextStyle(
              color: AppColors.black,
              fontFamily: 'Montserrat',
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: _orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Montserrat',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.black,
    foregroundColor: AppColors.white,
    disabledBackgroundColor: AppColors.gray200,
    disabledForegroundColor: _muted,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(vertical: 14),
    textStyle: const TextStyle(
      fontFamily: 'Montserrat',
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );
}

String _currency(num value) {
  final raw = value.round().toString();
  final reversed = raw.split('').reversed.toList();
  final groups = <String>[];
  for (var i = 0; i < reversed.length; i += 3) {
    groups.add(reversed.skip(i).take(3).toList().reversed.join());
  }
  return '\$ ${groups.reversed.join('.')}';
}

String _weight(num value) {
  if (value % 1 == 0) return value.round().toString();
  return value.toStringAsFixed(1);
}
