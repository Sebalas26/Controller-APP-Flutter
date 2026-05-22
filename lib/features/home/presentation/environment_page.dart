import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../shared/config/app_environment.dart';
import '../../../shared/theme/app_colors.dart';
import 'widgets/home_support_widgets.dart';

class EnvironmentPage extends StatefulWidget {
  const EnvironmentPage({
    super.key,
    required this.environment,
    required this.onEnvironmentChanged,
  });

  final AppEnvironment environment;
  final ValueChanged<AppEnvironment> onEnvironmentChanged;

  @override
  State<EnvironmentPage> createState() => _EnvironmentPageState();
}

class _EnvironmentPageState extends State<EnvironmentPage> {
  late AppEnvironment _selected = widget.environment;
  String? _status;
  bool _loading = false;

  Future<void> _pingHealth() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    final config = EnvironmentConfig.of(_selected);
    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ).get<dynamic>(config.healthUrl);
      if (!mounted) return;
      setState(() => _status = 'HTTP ${response.statusCode}');
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message ?? 'No fue posible conectar.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = EnvironmentConfig.of(_selected);
    final urls = <SummaryItem>[
      SummaryItem('Recogidas', config.recogidas),
      SummaryItem('Controller', config.controller),
      SummaryItem('Autenticacion', config.autenticacion),
      SummaryItem('Medios pago', config.mediosPago),
      SummaryItem('YAAP', config.yaap),
      SummaryItem('Notificaciones', config.torreNotificaciones),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ambientes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<AppEnvironment>(
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'Ambiente'),
            items: AppEnvironment.values
                .map(
                  (environment) => DropdownMenuItem(
                    value: environment,
                    child: Text(environment.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selected = value);
              widget.onEnvironmentChanged(value);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _pingHealth,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.health_and_safety_outlined),
            label: Text(_status ?? 'Probar health'),
          ),
          const SizedBox(height: 16),
          FormCard(
            children: urls
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          item.value,
                          style: const TextStyle(
                            color: AppColors.gray700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          FormCard(
            children: const [
              Text(
                'Endpoints portados',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              SelectableText(RestPaths.autenticaUsuario),
              SelectableText(RestPaths.versionApp),
              SelectableText(RestPaths.estadoGuia),
              SelectableText(RestPaths.reasignarGuias),
              SelectableText(RestPaths.mediosPago),
              SelectableText(RestPaths.bloquesPendientes),
            ],
          ),
        ],
      ),
    );
  }
}
