import '../../../shared/network/controller_api_config.dart';
import '../../entregas/entregas.dart';
import '../../login/login.dart';

class MultientregaRemoteRepository {
  MultientregaRemoteRepository({EntregasRemoteRepository? entregasRepository})
    : entregasRepository = entregasRepository ?? EntregasRemoteRepository();

  final EntregasRemoteRepository entregasRepository;

  Future<EntregaGuide?> searchGuide({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required String guideNumber,
  }) {
    return entregasRepository.searchGuide(
      config: config,
      appInformation: appInformation,
      guideNumber: guideNumber,
    );
  }

  Future<EntregaSyncResult> synchronizeDownload({
    required ControllerApiConfig config,
    required AppInformation appInformation,
    required EntregaPendingDownload download,
  }) {
    return entregasRepository.synchronizeDownload(
      config: config,
      appInformation: appInformation,
      download: download,
    );
  }
}
