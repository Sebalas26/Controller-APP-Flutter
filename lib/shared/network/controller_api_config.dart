class ControllerApiConfig {
  const ControllerApiConfig({
    required this.label,
    required this.controllerBaseUrl,
    required this.authenticationBaseUrl,
    required this.loginIntegrationBaseUrl,
    required this.syncFilesBaseUrl,
    required this.serviciosInterBaseUrl,
    required this.preenvioBaseUrl,
    required this.geoDireccionBaseUrl,
    required this.geoRefTokenBaseUrl,
    required this.admisionOfflineBaseUrl,
  });

  final String label;
  final String controllerBaseUrl;
  final String authenticationBaseUrl;
  final String loginIntegrationBaseUrl;
  final String syncFilesBaseUrl;
  final String serviciosInterBaseUrl;
  final String preenvioBaseUrl;
  final String geoDireccionBaseUrl;
  final String geoRefTokenBaseUrl;
  final String admisionOfflineBaseUrl;
}
