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
        VenderSectionTitle(
          icon: Icons.inventory_2_outlined,
          title: 'Datos del envio',
          subtitle: controller.appInformation.nombreCentroServicio,
        ),
        const SizedBox(height: 16),
        VenderResponsiveRow(
          children: [
            VenderTextInput(
              label: 'Numero de pregua/preenvio',
              controller: controller.preGuide,
              keyboardType: TextInputType.number,
            ),
            OutlinedButton.icon(
              onPressed: controller.busyRemote
                  ? null
                  : () => runAction(controller.verifyPreguide),
              icon: const Icon(Icons.search),
              label: const Text('Verificar'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        VenderCatalogDropdown(
          label: 'Ciudad de destino',
          options: catalogs.destinationCities,
          value: controller.destinationCity,
          onChanged: controller.selectDestination,
        ),
        const SizedBox(height: 14),
        VenderCatalogDropdown(
          label: 'Tipo de entrega',
          options: controller.deliveryTypes,
          value: controller.deliveryType,
          onChanged: controller.selectDeliveryType,
        ),
        const SizedBox(height: 14),
        VenderResponsiveRow(
          children: [
            VenderTextInput(
              label: '# de piezas',
              controller: controller.pieces,
              keyboardType: TextInputType.number,
            ),
            VenderTextInput(
              label: 'Peso Kg - bascula',
              controller: controller.weightScale,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            VenderTextInput(
              label: 'Peso Kg - volumetrico',
              controller: controller.weightVolume,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        VenderResponsiveRow(
          children: [
            VenderTextInput(
              label: 'Largo cm',
              controller: controller.length,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            VenderTextInput(
              label: 'Ancho cm',
              controller: controller.width,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            VenderTextInput(
              label: 'Alto cm',
              controller: controller.height,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controller.calculateVolumeWeight,
            icon: const Icon(Icons.straighten),
            label: const Text('Calcular peso volumetrico'),
          ),
        ),
        const SizedBox(height: 14),
        VenderResponsiveRow(
          children: [
            VenderTextInput(
              label: 'Valor comercial',
              controller: controller.declaredValue,
              keyboardType: TextInputType.number,
            ),
            VenderCatalogDropdown(
              label: 'Forma de pago',
              options: catalogs.paymentMethods,
              value: controller.paymentMethod,
              onChanged: controller.selectPaymentMethod,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: controller.paymentAtHome,
          onChanged: controller.setPaymentAtHome,
          title: const Text('Pago en casa'),
        ),
      ],
    );
  }
}
