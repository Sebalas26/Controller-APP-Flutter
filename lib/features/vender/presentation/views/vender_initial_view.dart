import 'package:flutter/material.dart';

import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

class VenderInitialView extends StatelessWidget {
  const VenderInitialView({
    super.key,
    required this.controller,
    required this.runAction,
  });

  final VenderFlowController controller;
  final Future<void> Function(Future<void> Function()) runAction;

  @override
  Widget build(BuildContext context) {
    final catalogs = controller.catalogs;
    if (catalogs == null) {
      return const VenderEmptyState(
        icon: Icons.storage_outlined,
        title: 'Catalogos no disponibles',
        message: 'No se cargaron datos locales de admision.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        VenderCatalogDropdown(
          label: 'Ciudad de destino',
          options: catalogs.destinationCities,
          value: controller.destinationCity,
          onChanged: controller.selectDestination,
          requiredField: true,
        ),
        VenderCatalogDropdown(
          label: 'Tipo de entrega',
          options: controller.deliveryTypes,
          value: controller.deliveryType,
          onChanged: controller.selectDeliveryType,
          requiredField: true,
        ),
        VenderTextInput(
          label: 'Numero Piezas',
          controller: controller.pieces,
          keyboardType: TextInputType.number,
          requiredField: true,
          center: true,
        ),
        VenderTextInput(
          label: 'Peso Kg - bascula',
          controller: controller.weightScale,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          requiredField: true,
          center: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 7),
          child: VenderNativeButton(
            label: 'Peso Kg Bascula (Opcional)',
            fullWidth: true,
            enabled: false,
            onPressed: controller.calculateVolumeWeight,
          ),
        ),
        VenderTextInput(
          label: 'Largo cm',
          controller: controller.length,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          center: true,
        ),
        VenderTextInput(
          label: 'Ancho cm',
          controller: controller.width,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          center: true,
        ),
        VenderTextInput(
          label: 'Alto cm',
          controller: controller.height,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          center: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: VenderNativeButton(
            label: 'Calcular peso volumetrico',
            fullWidth: true,
            icon: const Icon(Icons.straighten),
            onPressed: controller.calculateVolumeWeight,
          ),
        ),
        VenderTextInput(
          label: 'Peso Kg - volumetrico (Opcional)',
          controller: controller.weightVolume,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          center: true,
        ),
        VenderReadOnlyValue(
          label: 'Peso Total',
          value: controller.finalWeight.toStringAsFixed(2),
          requiredField: true,
          center: true,
        ),
        VenderTextInput(
          label: 'Valor comercial',
          controller: controller.declaredValue,
          keyboardType: TextInputType.number,
          requiredField: true,
          center: true,
        ),
        VenderCatalogDropdown(
          label: 'Forma de pago',
          options: catalogs.paymentMethods,
          value: controller.paymentMethod,
          onChanged: controller.selectPaymentMethod,
          requiredField: true,
        ),
        VenderYesNoSelector(
          title: 'Pago en casa',
          value: controller.paymentAtHome,
          onChanged: controller.setPaymentAtHome,
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
