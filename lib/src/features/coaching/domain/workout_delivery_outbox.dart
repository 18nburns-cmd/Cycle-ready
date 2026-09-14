enum WorkoutDeliveryOperationType { create, update, delete }

class WorkoutDeliveryOperation {
  const WorkoutDeliveryOperation({
    required this.deliveryId,
    required this.provider,
    required this.type,
    required this.idempotencyKey,
    required this.contentHash,
    required this.payload,
    required this.createdAt,
  });

  final String deliveryId;
  final String provider;
  final WorkoutDeliveryOperationType type;
  final String idempotencyKey;
  final String contentHash;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}

abstract interface class WorkoutDeliveryOutboxRepository {
  Future<bool> enqueue(WorkoutDeliveryOperation operation);
  Future<List<WorkoutDeliveryOperation>> pending({String? provider});
}
