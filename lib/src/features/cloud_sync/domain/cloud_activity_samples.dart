import 'dart:convert';

import 'package:crypto/crypto.dart';

class CloudActivitySample {
  const CloudActivitySample({
    required this.elapsedSeconds,
    this.heartRate,
    this.power,
    this.cadence,
    this.altitudeMetres,
    this.distanceMetres,
    this.latitude,
    this.longitude,
  });

  factory CloudActivitySample.fromJson(Map<String, Object?> json) =>
      CloudActivitySample(
        elapsedSeconds: _number(json['elapsedSeconds']).round(),
        heartRate: _nullableNumber(json['heartRate'])?.round(),
        power: _nullableNumber(json['power'])?.round(),
        cadence: _nullableNumber(json['cadence'])?.round(),
        altitudeMetres: _nullableNumber(json['altitudeMetres']),
        distanceMetres: _nullableNumber(json['distanceMetres']),
        latitude: _nullableNumber(json['latitude']),
        longitude: _nullableNumber(json['longitude']),
      );

  final int elapsedSeconds;
  final int? heartRate;
  final int? power;
  final int? cadence;
  final double? altitudeMetres;
  final double? distanceMetres;
  final double? latitude;
  final double? longitude;

  Map<String, Object?> toJson() => {
        'elapsedSeconds': elapsedSeconds,
        if (heartRate != null) 'heartRate': heartRate,
        if (power != null) 'power': power,
        if (cadence != null) 'cadence': cadence,
        if (altitudeMetres != null) 'altitudeMetres': altitudeMetres,
        if (distanceMetres != null) 'distanceMetres': distanceMetres,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

class CloudActivitySampleChunk {
  const CloudActivitySampleChunk({
    required this.activityId,
    required this.index,
    required this.samples,
    required this.contentHash,
  });

  factory CloudActivitySampleChunk.create({
    required String activityId,
    required int index,
    required List<CloudActivitySample> samples,
  }) {
    final immutable = List<CloudActivitySample>.unmodifiable(samples);
    final encoded =
        jsonEncode(immutable.map((sample) => sample.toJson()).toList());
    return CloudActivitySampleChunk(
      activityId: activityId,
      index: index,
      samples: immutable,
      contentHash: sha256.convert(utf8.encode(encoded)).toString(),
    );
  }

  final String activityId;
  final int index;
  final List<CloudActivitySample> samples;
  final String contentHash;

  int get firstElapsedSeconds => samples.first.elapsedSeconds;
  int get lastElapsedSeconds => samples.last.elapsedSeconds;
}

List<CloudActivitySampleChunk> chunkActivitySamples({
  required String activityId,
  required Iterable<CloudActivitySample> samples,
  int chunkSize = 500,
}) {
  if (chunkSize <= 0) throw ArgumentError.value(chunkSize, 'chunkSize');
  final ordered = samples.toList()
    ..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
  final chunks = <CloudActivitySampleChunk>[];
  for (var start = 0; start < ordered.length; start += chunkSize) {
    final end = (start + chunkSize).clamp(0, ordered.length);
    chunks.add(CloudActivitySampleChunk.create(
      activityId: activityId,
      index: chunks.length,
      samples: ordered.sublist(start, end),
    ));
  }
  return chunks;
}

abstract interface class CloudActivitySampleRepository {
  Future<List<CloudActivitySample>> fetchForActivity(String activityId);

  Future<void> replaceActivityChunks(
    String activityId,
    List<CloudActivitySampleChunk> chunks,
  );
}

double _number(Object? value) => _nullableNumber(value) ?? 0;
double? _nullableNumber(Object? value) => switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
