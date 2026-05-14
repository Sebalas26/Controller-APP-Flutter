import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/login_data.dart';
import '../../../shared/network/controller_api_config.dart';

class LoginPage<T> extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.environment,
    required this.environments,
    required this.environmentLabel,
    required this.rememberedUser,
    required this.onEnvironmentChanged,
    required this.apiConfig,
    required this.loginRepository,
    required this.onLogin,
  });

  final T environment;
  final Iterable<T> environments;
  final String Function(T environment) environmentLabel;
  final String rememberedUser;
  final ValueChanged<T> onEnvironmentChanged;
  final ControllerApiConfig apiConfig;
  final ControllerLoginRepository loginRepository;
  final Future<void> Function(AuthenticatedSession session, bool rememberUser)
  onLogin;

  @override
  State<LoginPage<T>> createState() => _LoginPageState<T>();
}

class _LoginPageState<T> extends State<LoginPage<T>> {
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  bool _rememberUser = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _progressMessage;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.rememberedUser);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.length < 4 || username.length > 22) {
      _showSnack('El usuario debe tener entre 4 y 22 caracteres.');
      return;
    }

    if (password.isEmpty) {
      _showSnack('Ingresa la contrasena.');
      return;
    }

    setState(() {
      _isLoading = true;
      _progressMessage = 'Preparando inicio de sesion...';
    });

    try {
      final result = await widget.loginRepository.authenticate(
        config: widget.apiConfig,
        username: username,
        password: password,
        rememberUser: _rememberUser,
        onProgress: _setProgress,
      );

      if (result.isOffline) {
        await widget.onLogin(result.offlineSession!, _rememberUser);
        return;
      }

      final draft = result.draft!;
      final selectedLocation = draft.credential.locations.length == 1
          ? draft.credential.locations.first
          : await _selectLocation(draft.credential.locations);
      if (selectedLocation == null) return;

      final session = await widget.loginRepository.completeLogin(
        draft: draft,
        selectedLocation: selectedLocation,
        rememberUser: _rememberUser,
        onProgress: _setProgress,
      );
      await widget.onLogin(session, _rememberUser);
    } on LoginException catch (error) {
      _showSnack(error.message);
    } on DioException catch (error) {
      _showSnack(error.message ?? 'No fue posible conectar con el servidor.');
    } on Object catch (error) {
      _showSnack('No fue posible iniciar sesion: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _progressMessage = null;
        });
      }
    }
  }

  void _setProgress(String message) {
    if (!mounted) return;
    setState(() => _progressMessage = message);
  }

  Future<AuthorizedLocation?> _selectLocation(
    List<AuthorizedLocation> locations,
  ) {
    return showDialog<AuthorizedLocation>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecciona ubicacion'),
          content: SizedBox(
            width: 420,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: locations.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final location = locations[index];
                return ListTile(
                  leading: const Icon(Icons.store_mall_directory_outlined),
                  title: Text(location.serviceCenterName),
                  subtitle: Text(location.cityName),
                  onTap: () => Navigator.of(context).pop(location),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LoginColors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Image.asset(
                    'assets/images/logo_interrapidisimo.png',
                    height: 42,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'assets/images/drone_flying_with_package.png',
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          const _LoginFieldLabel('Usuario'),
                          TextField(
                            controller: _usernameController,
                            enabled: !_isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(),
                          ),
                          const SizedBox(height: 16),
                          const _LoginFieldLabel('Contrasena'),
                          TextField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => unawaited(_submit()),
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Mostrar'
                                    : 'Ocultar',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: _LoginColors.black,
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Recordar usuario',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Switch(
                                value: _rememberUser,
                                activeThumbColor: _LoginColors.black,
                                onChanged: _isLoading
                                    ? null
                                    : (value) =>
                                          setState(() => _rememberUser = value),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _isLoading
                                ? null
                                : () => unawaited(_submit()),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _LoginColors.white,
                                    ),
                                  )
                                : const Text('Ingresar'),
                          ),
                          if (_progressMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _progressMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _LoginColors.gray700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          DropdownButtonFormField<T>(
                            initialValue: widget.environment,
                            decoration: const InputDecoration(
                              labelText: 'Ambiente',
                              fillColor: _LoginColors.gray100,
                            ),
                            items: widget.environments
                                .map(
                                  (environment) => DropdownMenuItem<T>(
                                    value: environment,
                                    child: Text(
                                      widget.environmentLabel(environment),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      widget.onEnvironmentChanged(value);
                                    }
                                  },
                          ),
                          const SizedBox(height: 24),
                          const Center(
                            child: Text(
                              'V 1.1109136',
                              style: TextStyle(
                                fontSize: 10,
                                color: _LoginColors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFieldLabel extends StatelessWidget {
  const _LoginFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _LoginColors.black,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoginColors {
  static const black = Color(0xFF212529);
  static const white = Color(0xFFFFFFFF);
  static const gray100 = Color(0xFFF9F9F9);
  static const gray700 = Color(0xFF696F79);
}
