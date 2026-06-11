import 'package:flutter/material.dart';

import '../../models/vender_models.dart';
import '../controllers/vender_flow_controller.dart';
import '../widgets/vender_customer_key_dialog.dart';
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
        const SizedBox(height: 8),
        VenderResponsiveRow(
          children: [
            VenderTextInput(
              label: 'Identificacion',
              controller: _document,
              keyboardType: TextInputType.number,
              requiredField: true,
              tooltip: 'Ingresa el documento del cliente.',
              onFocusLost: () {
                _lookupCustomerKey(context);
              },
            ),
            VenderTextInput(
              label: 'Celular',
              controller: _phone,
              keyboardType: TextInputType.phone,
              requiredField: true,
              tooltip: 'Ingresa el celular del cliente.',
              onFocusLost: () {
                _lookupCustomerKey(context);
              },
            ),
          ],
        ),
        if (!_isSender)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
            child: TextButton.icon(
              onPressed: controller.copySenderToRecipient,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copiar remitente'),
            ),
          ),
        VenderResponsiveRow(
          children: [
            VenderTextInput(
              label: 'Nombre / Razon social',
              controller: _name,
              requiredField: true,
              textCapitalization: TextCapitalization.characters,
            ),
            VenderTextInput(
              label: 'Primer apellido',
              controller: _firstLastName,
              textCapitalization: TextCapitalization.characters,
            ),
            VenderTextInput(
              label: 'Segundo apellido',
              controller: _secondLastName,
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        VenderResponsiveRow(
          children: [
            VenderCatalogDropdown(
              label: 'Tipo direccion',
              options: catalogs.addressTypes,
              value: _addressType,
              onChanged: (value) => controller.setAddressType(kind, value),
              requiredField: true,
            ),
            VenderTextInput(
              label: 'Via / calle',
              controller: _street,
              requiredField: true,
              textCapitalization: TextCapitalization.characters,
            ),
            VenderTextInput(
              label: 'Numero',
              controller: _number,
              requiredField: true,
            ),
          ],
        ),
        VenderYesNoSelector(
          title: 'Sur',
          value: _south,
          onChanged: (value) => controller.setSouth(kind, value),
        ),
        VenderResponsiveRow(
          children: [
            VenderCatalogDropdown(
              label: 'Tipo inmueble',
              options: catalogs.propertyTypes,
              value: _propertyType,
              onChanged: (value) => controller.setPropertyType(kind, value),
              requiredField: true,
            ),
            VenderTextInput(
              label: 'Complemento',
              controller: _complement,
              textCapitalization: TextCapitalization.characters,
            ),
            VenderTextInput(
              label: 'Barrio',
              controller: _neighborhood,
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        VenderTextInput(
          label: 'Direccion',
          controller: _address,
          maxLines: 2,
          requiredField: true,
          textCapitalization: TextCapitalization.characters,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: VenderNativeButton(
            label: 'Georreferenciar',
            fullWidth: true,
            icon: const Icon(Icons.my_location),
            onPressed: controller.busyRemote
                ? null
                : () => runAction(() => controller.geocodePerson(kind)),
          ),
        ),
        VenderTextInput(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        VenderYesNoSelector(
          title: 'Enviar notificacion',
          value: _notification,
          onChanged: (value) => controller.setNotification(kind, value),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _lookupCustomerKey(BuildContext context) async {
    await runAction(() async {
      final result = await controller.lookupPersonFromFocus(kind);
      if (result == null || !result.requiresConfirmation || !context.mounted) {
        return;
      }
      final accepted = await showVenderCustomerKeyDialog(context, result);
      if (accepted == true) {
        controller.acceptCustomerKey(kind, result);
      } else {
        controller.cancelCustomerKey(kind);
      }
    });
  }

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
