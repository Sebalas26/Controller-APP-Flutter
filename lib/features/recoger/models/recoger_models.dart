class RecogidaItem {
  const RecogidaItem({
    required this.id,
    required this.type,
    required this.address,
    required this.customerName,
    required this.description,
    required this.time,
    this.synced = false,
  });

  final String id;
  final String type;
  final String address;
  final String customerName;
  final String description;
  final String time;
  final bool synced;
}

class RecogidaPreenvio {
  const RecogidaPreenvio({
    required this.guideNumber,
    required this.sender,
    required this.recipient,
    required this.value,
    required this.verified,
    required this.cancelled,
  });

  final String guideNumber;
  final String sender;
  final String recipient;
  final int value;
  final bool verified;
  final bool cancelled;
}
