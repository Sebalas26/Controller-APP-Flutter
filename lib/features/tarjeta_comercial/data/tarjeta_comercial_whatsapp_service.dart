import 'package:url_launcher/url_launcher.dart';

class TarjetaComercialWhatsappService {
  const TarjetaComercialWhatsappService();

  Future<bool> share({
    required String nationalPhone,
    required String message,
  }) async {
    final phone = nationalPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty || message.trim().isEmpty) return false;

    final whatsappUri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: {'phone': phone, 'text': message},
    );
    if (await canLaunchUrl(whatsappUri)) {
      return launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
