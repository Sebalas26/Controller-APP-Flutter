import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/config/app_environment.dart';
import '../../../shared/constants/app_assets.dart';
import '../../../shared/theme/app_colors.dart';
import '../../vender/impresion/services/print_device_service.dart';
import '../models/controller_session.dart';
import '../models/home_module.dart';
import 'environment_page.dart';
import 'module_page.dart';
import 'native_routes_page.dart';
import 'notifications_page.dart';
import 'widgets/home_banner.dart';
import 'widgets/home_footer.dart';
import 'widgets/home_header.dart';
import 'widgets/home_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.environment,
    required this.onEnvironmentChanged,
    required this.onLogout,
  });

  final ControllerSession session;
  final AppEnvironment environment;
  final ValueChanged<AppEnvironment> onEnvironmentChanged;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _guideController = TextEditingController();
  final _printDeviceService = PrintDeviceService();
  bool _printingSewooTest = false;

  @override
  void dispose() {
    _guideController.dispose();
    super.dispose();
  }

  void _openModule(AppModule module) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModulePage(
          module: module,
          session: widget.session,
          config: EnvironmentConfig.of(widget.environment),
        ),
      ),
    );
  }

  Future<void> _launchTracking() async {
    final guide = _guideController.text.trim();
    if (guide.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el numero de guia.')),
      );
      return;
    }

    final url = Uri.parse(
      EnvironmentConfig.of(widget.environment).trackingUrl(guide),
    );
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(url.toString())));
    }
  }

  Future<void> _printSewooTest() async {
    if (_printingSewooTest) return;
    setState(() => _printingSewooTest = true);
    try {
      final diagnostics = await _printDeviceService.printSewooTestDiagnostics();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Diagnostico SEWO'),
          content: SingleChildScrollView(
            child: SelectableText(
              diagnostics,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      final printed = diagnostics.contains('RESULTADO: OK');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printed
                ? 'Prueba SEWO enviada correctamente.'
                : 'Diagnostico SEWO finalizado con error.',
          ),
          backgroundColor: printed ? const Color(0xFF01623D) : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _printingSewooTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryModules = appModules.where((item) => item.primary).toList();
    final functionalModules = appModules
        .where((item) => !item.primary)
        .toList();
    final footerUser = widget.session.username.trim().isNotEmpty
        ? widget.session.username.trim().toUpperCase()
        : widget.session.displayName.toUpperCase();
    final footerText =
        '$footerUser - ID ${widget.session.appInformation.idCentroServicio}'
        ' - V ${AppStrings.appVersionName}'
        ' - M${widget.session.appInformation.idMensajero}';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      drawer: AppNavigationDrawer(
        session: widget.session,
        environment: widget.environment,
        onEnvironmentChanged: widget.onEnvironmentChanged,
        onLogout: widget.onLogout,
      ),
      body: SafeArea(
        child: Column(
          children: [
            HomeHeader(
              onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
              onNotificationsPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
              offline: widget.session.offline,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 15, 24, 0),
                      child: SearchGuideField(
                        controller: _guideController,
                        onSubmit: _launchTracking,
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: OutlinedButton.icon(
                          onPressed: _printingSewooTest
                              ? null
                              : _printSewooTest,
                          icon: const Icon(Icons.print_outlined),
                          label: Text(
                            _printingSewooTest
                                ? 'Probando SEWO...'
                                : 'Prueba SEWO iOS',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const SectionTitle(icon: Icons.check, text: 'Principales'),
                    PrimaryModulesLayout(
                      modules: primaryModules,
                      onSelected: _openModule,
                    ),
                    const SizedBox(height: 5),
                    const SectionTitle(icon: Icons.add, text: 'Funciones'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 17),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: functionalModules.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisExtent: 85,
                            ),
                        itemBuilder: (context, index) {
                          final module = functionalModules[index];
                          return ModuleCard(
                            module: module,
                            onTap: () => _openModule(module),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    HomeBanner(environment: widget.environment),
                  ],
                ),
              ),
            ),
            HomeFooter(userDetails: footerText),
          ],
        ),
      ),
    );
  }
}

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    super.key,
    required this.session,
    required this.environment,
    required this.onEnvironmentChanged,
    required this.onLogout,
  });

  final ControllerSession session;
  final AppEnvironment environment;
  final ValueChanged<AppEnvironment> onEnvironmentChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xB3000000),
      elevation: 0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () {
                        // Agregar acción aquí
                      },
                      child: SvgPicture.asset(
                        'assets/vectors/button_image_x.svg',
                        height: 20,
                        width: 20,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/vectors/solar_user_outline.svg',
                        height: 34,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              environment.appName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: Colors.white.withOpacity(0.12)),

            ListTile(
              title: const Text(
                'Reimprimir',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                  decorationThickness: 1.0,
                  decorationStyle: TextDecorationStyle.solid,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
            ),

            ListTile(
              title: const Text(
                'Reporte cajas',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                  decorationThickness: 1.0,
                  decorationStyle: TextDecorationStyle.solid,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EnvironmentPage(
                      environment: environment,
                      onEnvironmentChanged: onEnvironmentChanged,
                    ),
                  ),
                );
              },
            ),

            ListTile(
              title: const Text(
                'Sincronizar',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                  decorationThickness: 1.0,
                  decorationStyle: TextDecorationStyle.solid,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NativeRoutesPage()),
                );
              },
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onLogout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
