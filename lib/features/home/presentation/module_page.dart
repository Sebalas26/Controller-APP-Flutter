import 'package:flutter/material.dart';

import '../reimpresion/reimpresion.dart';
import '../../bloques/bloques.dart';
import '../../entregas/entregas.dart';
import '../../recoger/recoger.dart';
import '../../vender/vender.dart';
import '../../../shared/config/app_environment.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/controller_session.dart';
import '../models/home_module.dart';
import 'widgets/home_support_widgets.dart';

class ModulePage extends StatelessWidget {
  const ModulePage({
    super.key,
    required this.module,
    required this.session,
    required this.config,
  });

  final AppModule module;
  final ControllerSession session;
  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    if (module.id == 'vender') {
      return Scaffold(
        body: SafeArea(
          child: VenderPage(
            appInformation: session.appInformation,
            apiConfig: config.toApiConfig(),
            offline: session.offline,
          ),
        ),
      );
    }

    if (module.id == 'entregar') {
      return Scaffold(
        body: SafeArea(
          child: EntregasPage(
            appInformation: session.appInformation,
            apiConfig: config.toApiConfig(),
            offline: session.offline,
          ),
        ),
      );
    }

    if (module.id == 'recoger') {
      return Scaffold(
        body: SafeArea(
          child: RecogerPage(
            appInformation: session.appInformation,
            apiConfig: config.toApiConfig(),
            offline: session.offline,
          ),
        ),
      );
    }

    if (module.id == 'bloques') {
      return Scaffold(
        body: BloquesPage(
          appInformation: session.appInformation,
          apiConfig: config.toApiConfig(),
          offline: session.offline,
        ),
      );
    }

    if (module.id == 'reimprimir') {
      return Scaffold(
        body: ReimpresionPage(
          appInformation: session.appInformation,
          apiConfig: config.toApiConfig(),
          offline: session.offline,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(module.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModuleHeader(module: module, config: config),
            const SizedBox(height: 12),
            _bodyFor(module),
          ],
        ),
      ),
    );
  }

  Widget _bodyFor(AppModule module) {
    switch (module.id) {
      case 'vender':
        return VenderPage(
          appInformation: session.appInformation,
          apiConfig: config.toApiConfig(),
          offline: session.offline,
        );
      case 'entregar':
        return EntregasPage(
          appInformation: session.appInformation,
          apiConfig: config.toApiConfig(),
          offline: session.offline,
        );
      case 'recoger':
        return const PickupBody();
      case 'asignar':
        return const AssignmentBody();
      case 'mis_pagos':
        return PaymentsBody(config: config);
      case 'estado_cuenta':
        return const AccountStatusBody();
      case 'mis_mensajeros':
        return const CouriersBody();
      case 'reimprimir':
        return ReimpresionPage(
          appInformation: session.appInformation,
          apiConfig: config.toApiConfig(),
          offline: session.offline,
        );
      case 'anular':
        return const CancelGuideBody();
      case 'bloques':
        return BloquesPage(
          appInformation: session.appInformation,
          apiConfig: config.toApiConfig(),
          offline: session.offline,
        );
      case 'enrutamiento':
        return const RoutingBody();
      case 'auditoria':
        return const AuditBody();
      case 'prepago':
        return const PrepagoBody();
      default:
        return GenericWorkflowBody(module: module);
    }
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.module, required this.config});

  final AppModule module;
  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(module.icon, color: AppColors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    config.environment.label,
                    style: const TextStyle(color: AppColors.gray700),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: module.legacyRoute,
              child: const Icon(Icons.info_outline, color: AppColors.gray700),
            ),
          ],
        ),
      ),
    );
  }
}

class AdmissionBody extends StatelessWidget {
  const AdmissionBody({super.key, required this.config});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Numero de preenvio'),
        const TextField(keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        const FieldLabel('Ciudad de destino'),
        const TextField(),
        const SizedBox(height: 14),
        const FieldLabel('Piezas y peso'),
        const Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: '# piezas'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'Peso kg'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SummaryStrip(
          items: [
            SummaryItem('Base', config.controller),
            const SummaryItem('Modo', 'Online / Offline'),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Cotizar'),
        ),
      ],
    );
  }
}

class DeliveryBody extends StatelessWidget {
  const DeliveryBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabWorkflow(
      tabs: ['En zona', 'Entregadas', 'Devoluciones'],
      children: [
        GuideList(status: 'En zona', icon: Icons.location_on_outlined),
        GuideList(status: 'Entregada', icon: Icons.check_circle_outline),
        GuideList(status: 'Devolucion', icon: Icons.assignment_return_outlined),
      ],
    );
  }
}

class PickupBody extends StatelessWidget {
  const PickupBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabWorkflow(
      tabs: ['Disponibles', 'Reservadas', 'Efectivas'],
      children: [
        GuideList(status: 'Disponible', icon: Icons.inbox_outlined),
        GuideList(status: 'Reservada', icon: Icons.bookmark_border),
        GuideList(status: 'Efectiva', icon: Icons.task_alt_outlined),
      ],
    );
  }
}

class AssignmentBody extends StatefulWidget {
  const AssignmentBody({super.key});

  @override
  State<AssignmentBody> createState() => _AssignmentBodyState();
}

class _AssignmentBodyState extends State<AssignmentBody> {
  final _courierController = TextEditingController();
  final _guideController = TextEditingController();
  final _guides = <String>[];

  @override
  void dispose() {
    _courierController.dispose();
    _guideController.dispose();
    super.dispose();
  }

  void _addGuide() {
    final guide = _guideController.text.trim();
    if (guide.isEmpty) return;
    setState(() {
      _guides.add(guide);
      _guideController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Seleccionar mensajero'),
        TextField(
          controller: _courierController,
          decoration: const InputDecoration(
            hintText: 'Seleccionar apoyo',
            suffixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Ingresar guias'),
        TextField(
          controller: _guideController,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => _addGuide(),
          decoration: InputDecoration(
            hintText: 'Numero guia',
            suffixIcon: IconButton(
              tooltip: 'Agregar guia',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _addGuide,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Total asignado: ${_guides.length}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ..._guides.map(
          (guide) => GuideTile(
            guide: guide,
            status: 'Pendiente',
            icon: Icons.local_shipping_outlined,
            onDelete: () => setState(() => _guides.remove(guide)),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _guides.isEmpty ? null : () {},
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('Asignar planilla'),
        ),
      ],
    );
  }
}

class PaymentsBody extends StatefulWidget {
  const PaymentsBody({super.key, required this.config});

  final EnvironmentConfig config;

  @override
  State<PaymentsBody> createState() => _PaymentsBodyState();
}

class _PaymentsBodyState extends State<PaymentsBody> {
  String _method = 'Nequi';
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Nequi', 'Link de pago', 'Efectivo', 'Inter Pay']
              .map(
                (method) => ChoiceChip(
                  label: Text(method),
                  selected: method == _method,
                  onSelected: (_) => setState(() => _method = method),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Valor a cobrar'),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: r'$ '),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Telefono'),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        SummaryStrip(
          items: [
            SummaryItem('Medio', _method),
            SummaryItem('Base', widget.config.mediosPago),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.send_outlined),
          label: const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}

class AccountStatusBody extends StatelessWidget {
  const AccountStatusBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: const [
        DashboardTile(
          title: 'Saldo por centro de servicio',
          value: r'$ 0',
          icon: Icons.account_balance_wallet_outlined,
        ),
        DashboardTile(
          title: 'Guias entregadas',
          value: '0',
          icon: Icons.check_circle_outline,
        ),
        DashboardTile(
          title: 'Pendiente por legalizar',
          value: '0',
          icon: Icons.pending_actions_outlined,
        ),
      ],
    );
  }
}

class CouriersBody extends StatelessWidget {
  const CouriersBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Buscar apoyo'),
        const TextField(
          decoration: InputDecoration(
            hintText: 'Nombre, telefono o identificacion',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Nuevo Mensajero'),
        ),
        const SizedBox(height: 12),
        const GuideTile(
          guide: 'Apoyo disponible',
          status: 'Activo',
          icon: Icons.person_outline,
        ),
      ],
    );
  }
}

class ReprintBody extends StatelessWidget {
  const ReprintBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Numero de guia'),
        const TextField(keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: const [
            FilterChip(label: Text('Zebra'), selected: true, onSelected: null),
            FilterChip(
              label: Text('Woosim'),
              selected: false,
              onSelected: null,
            ),
            FilterChip(label: Text('Sewoo'), selected: false, onSelected: null),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.print_outlined),
          label: const Text('Reimprimir'),
        ),
      ],
    );
  }
}

class CancelGuideBody extends StatelessWidget {
  const CancelGuideBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Numero de guia'),
        const TextField(keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        const FieldLabel('Motivo anulacion'),
        DropdownButtonFormField<String>(
          initialValue: 'Cliente solicita anulacion',
          items: const [
            DropdownMenuItem(
              value: 'Cliente solicita anulacion',
              child: Text('Cliente solicita anulacion'),
            ),
            DropdownMenuItem(
              value: 'Error en admision',
              child: Text('Error en admision'),
            ),
            DropdownMenuItem(value: 'Otro', child: Text('Otro')),
          ],
          onChanged: (_) {},
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.block_outlined),
          label: const Text('Anular guia'),
        ),
      ],
    );
  }
}

class BlocksBody extends StatelessWidget {
  const BlocksBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabWorkflow(
      tabs: ['Pendientes', 'En gestion', 'Cerrados'],
      children: [
        GuideList(status: 'Pendiente bloque', icon: Icons.all_inbox_outlined),
        GuideList(status: 'En gestion', icon: Icons.inventory_outlined),
        GuideList(status: 'Cerrado', icon: Icons.task_alt_outlined),
      ],
    );
  }
}

class RoutingBody extends StatelessWidget {
  const RoutingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const DashboardTile(
          title: 'Guias ruta',
          value: '0',
          icon: Icons.alt_route_outlined,
        ),
        const DashboardTile(
          title: 'Enrutamientos diarios',
          value: '20',
          icon: Icons.calendar_month_outlined,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Abrir mapa'),
        ),
      ],
    );
  }
}

class AuditBody extends StatelessWidget {
  const AuditBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabWorkflow(
      tabs: ['Por aprobar', 'Rechazadas', 'No aplican'],
      children: [
        GuideList(status: 'Por aprobar', icon: Icons.pending_actions_outlined),
        GuideList(status: 'Rechazada', icon: Icons.cancel_outlined),
        GuideList(status: 'No aplica', icon: Icons.info_outline),
      ],
    );
  }
}

class PrepagoBody extends StatelessWidget {
  const PrepagoBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const DashboardTile(
          title: 'Cuenta prepago',
          value: r'$ 0',
          icon: Icons.credit_card_outlined,
        ),
        const SizedBox(height: 12),
        const FieldLabel('Codigo de seguridad'),
        const TextField(keyboardType: TextInputType.number, maxLength: 6),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.lock_open_outlined),
          label: const Text('Validar codigo'),
        ),
      ],
    );
  }
}

class GenericWorkflowBody extends StatelessWidget {
  const GenericWorkflowBody({super.key, required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      children: [
        const FieldLabel('Buscar'),
        TextField(decoration: InputDecoration(hintText: module.title)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: Icon(module.icon),
          label: Text(module.title),
        ),
      ],
    );
  }
}
