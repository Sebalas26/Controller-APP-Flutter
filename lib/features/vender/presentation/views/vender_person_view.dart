import 'package:flutter/material.dart';

import '../../models/vender_models.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_form_widgets.dart';

class VenderPersonView extends StatelessWidget {
  const VenderPersonView({
    super.key,
    required this.controller,
    required this.kind,
    required this.runAction,
  });

  final VenderFlowController controller;
  final VenderPersonKind kind;
  final Future<void> Function(Future<void> Function()) runAction;

  bool get _isSender => kind == VenderPersonKind.sender;

  @override
  Widget build(BuildContext context) {
    final catalogs = controller.catalogs;
    if (catalogs == null) {
      return const VenderEmptyState(
        icon: Icons.person_outline,
        title: 'Datos no disponibles',
        message: 'No se cargaron catalogos de persona y direccion.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VenderSectionTitle(
          icon: _isSender ? Icons.person_outline : Icons.location_on_outlined,
          title: _isSender ? 'Datos remitente' : 'Datos destinatario',
          subtitle: _isSender
              ? controller.appInformation.nombreCiudad
              : controller.destinationCity?.label,
        ),
        const SizedBox(height: 16),
        VenderResponsiveRow(
          children: [
            VenderCatalogDropdown(
              label: 'Tipo identificacion',
              options: catalogs.identificationTypes,
              value: _identificationType,
              onChanged: (value) =>
                  controller.setIdentificationType(kind, value),
            ),
            VenderTextInput(
              label: 'Documento',
              controller: _document,
              keyboardType: TextInputType.number,
            ),
            VenderTextInput(
              label: 'Celular',
              controller: _phone,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: controller.busyRemote
                  ? null
                  : () => runAction(() => controller.lookupPerson(kind)),
              icon: const Icon(Icons.manage_search),
              label: const Text('Consultar cliente'),
            ),
            if (!_isSender)
              TextButton.icon(
                onPressed: controller.copySenderToRecipient,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copiar remitente'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        VenderResponsiveRow(
          children: [
            VenderTextInput(label: 'Nombres', controller: _name),
            VenderTextInput(
              label: 'Primer apellido',
              controller: _firstLastName,
            ),
            VenderTextInput(
              label: 'Segundo apellido',
              controller: _secondLastName,
            ),
          ],
        ),
        const SizedBox(height: 14),
        VenderResponsiveRow(
          children: [
            VenderCatalogDropdown(
              label: 'Tipo direccion',
              options: catalogs.addressTypes,
              value: _addressType,
              onChanged: (value) => controller.setAddressType(kind, value),
            ),
            VenderTextInput(label: 'Via / calle', controller: _street),
            VenderTextInput(label: 'Numero', controller: _number),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _south,
          onChanged: (value) => controller.setSouth(kind, value),
          title: const Text('Sur'),
        ),
        const SizedBox(height: 4),
        VenderResponsiveRow(
          children: [
            VenderCatalogDropdown(
              label: 'Tipo inmueble',
              options: catalogs.propertyTypes,
              value: _propertyType,
              onChanged: (value) => controller.setPropertyType(kind, value),
            ),
            VenderTextInput(label: 'Complemento', controller: _complement),
            VenderTextInput(label: 'Barrio', controller: _neighborhood),
          ],
        ),
        const SizedBox(height: 14),
        VenderTextInput(label: 'Direccion', controller: _address, maxLines: 2),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: controller.busyRemote
                ? null
                : () => runAction(() => controller.geocodePerson(kind)),
            icon: const Icon(Icons.my_location),
            label: const Text('Georreferenciar'),
          ),
        ),
        const SizedBox(height: 14),
        VenderTextInput(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _notification,
          onChanged: (value) => controller.setNotification(kind, value),
          title: const Text('Enviar notificacion'),
        ),
      ],
    );
  }

  CatalogOption? get _identificationType => _isSender
      ? controller.senderIdentificationType
      : controller.recipientIdentificationType;
  CatalogOption? get _addressType => _isSender
      ? controller.senderAddressType
      : controller.recipientAddressType;
  CatalogOption? get _propertyType => _isSender
      ? controller.senderPropertyType
      : controller.recipientPropertyType;

  TextEditingController get _document =>
      _isSender ? controller.senderDocument : controller.recipientDocument;
  TextEditingController get _phone =>
      _isSender ? controller.senderPhone : controller.recipientPhone;
  TextEditingController get _name =>
      _isSender ? controller.senderName : controller.recipientName;
  TextEditingController get _firstLastName => _isSender
      ? controller.senderFirstLastName
      : controller.recipientFirstLastName;
  TextEditingController get _secondLastName => _isSender
      ? controller.senderSecondLastName
      : controller.recipientSecondLastName;
  TextEditingController get _street =>
      _isSender ? controller.senderStreet : controller.recipientStreet;
  TextEditingController get _number =>
      _isSender ? controller.senderNumber : controller.recipientNumber;
  TextEditingController get _complement =>
      _isSender ? controller.senderComplement : controller.recipientComplement;
  TextEditingController get _neighborhood => _isSender
      ? controller.senderNeighborhood
      : controller.recipientNeighborhood;
  TextEditingController get _address =>
      _isSender ? controller.senderAddress : controller.recipientAddress;
  TextEditingController get _email =>
      _isSender ? controller.senderEmail : controller.recipientEmail;

  bool get _south =>
      _isSender ? controller.senderSouth : controller.recipientSouth;
  bool get _notification => _isSender
      ? controller.senderNotification
      : controller.recipientNotification;
}
