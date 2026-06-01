class TarjetaComercialException implements Exception {
  const TarjetaComercialException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TarjetaComercialItem {
  const TarjetaComercialItem({
    required this.description,
    required this.messageTitle,
    required this.messageDetail,
  });

  final String description;
  final String messageTitle;
  final String messageDetail;

  bool get hasDescription => description.trim().isNotEmpty;
}
