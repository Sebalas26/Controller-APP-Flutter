import '../../entregas/entregas.dart';

class MultientregaException implements Exception {
  const MultientregaException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MultientregaGuide {
  const MultientregaGuide({
    required this.guide,
    required this.photoBase64,
    required this.requiresSeal,
    required this.createdAt,
  });

  final EntregaGuide guide;
  final String photoBase64;
  final bool requiresSeal;
  final DateTime createdAt;

  String get guideNumber => guide.guideNumber;
  bool get hasPhoto => photoBase64.trim().isNotEmpty;
  int get valueToCollect => guide.valueToCollect;

  MultientregaGuide copyWith({
    EntregaGuide? guide,
    String? photoBase64,
    bool? requiresSeal,
    DateTime? createdAt,
  }) {
    return MultientregaGuide(
      guide: guide ?? this.guide,
      photoBase64: photoBase64 ?? this.photoBase64,
      requiresSeal: requiresSeal ?? this.requiresSeal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MultientregaReceiverData {
  const MultientregaReceiverData({
    required this.name,
    required this.document,
    required this.observations,
  });

  final String name;
  final String document;
  final String observations;

  String get numericDocument => document.replaceAll(RegExp(r'[^0-9]'), '');

  Map<String, dynamic> toJson() {
    return {
      'nombre': name,
      'documento': numericDocument,
      'observaciones': observations,
    };
  }
}
