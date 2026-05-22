import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/config/app_environment.dart';
import '../../../shared/constants/app_assets.dart';
import '../../../shared/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final primaryModules = appModules.where((item) => item.primary).toList();
    final functionalModules = appModules
        .where((item) => !item.primary)
        .toList();
    final statusLabel = widget.session.offline
        ? 'Offline'
        : widget.session.syncStatus?.completed == true
        ? 'Sync OK'
        : widget.environment.label;

    return Scaffold(
      key: _scaffoldKey,
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
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
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
                    const SizedBox(height: 18),
                    const SectionTitle(
                      icon: Icons.check_circle_outline,
                      text: 'Principales',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: primaryModules.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.05,
                            ),
                        itemBuilder: (context, index) {
                          final module = primaryModules[index];
                          return ModuleCard(
                            module: module,
                            large: true,
                            onTap: () => _openModule(module),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    HomeBanner(environment: widget.environment),
                    const SizedBox(height: 18),
                    const SectionTitle(
                      icon: Icons.more_horiz,
                      text: 'Funcionales',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: functionalModules.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.95,
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
                  ],
                ),
              ),
            ),
            HomeFooter(
              userName: widget.session.displayName,
              statusLabel: statusLabel,
            ),
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
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(AppAssets.logoInterrapidisimo, height: 34),
                  const SizedBox(height: 22),
                  Text(
                    session.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    environment.appName,
                    style: const TextStyle(color: AppColors.gray700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Notificaciones'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_queue_outlined),
              title: const Text('Ambientes'),
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
              leading: const Icon(Icons.route_outlined),
              title: const Text('Rutas Android'),
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
                onPressed: () {
                  Navigator.pop(context);
                  onLogout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesion'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
