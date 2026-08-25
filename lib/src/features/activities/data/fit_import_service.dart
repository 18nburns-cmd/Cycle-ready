import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fit_sdk/fit_sdk.dart';

class ParsedFitSample {
  const ParsedFitSample({
    required this.elapsedSeconds,
    this.heartRate,
    this.power,
    this.cadence,
    this.altitudeMetres,
    this.distanceMetres,
  });
  final int elapsedSeconds;
  final int? heartRate;
  final int? power;
  final int? cadence;
  final double? altitudeMetres;
  final double? distanceMetres;
}

class ParsedFitActivity {
  const ParsedFitActivity({
    required this.hash,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMetres,
    required this.elevationMetres,
    this.averageHeartRate,
    this.maximumHeartRate,
    this.averagePower,
    this.maximumPower,
    this.normalisedPower,
    this.averageCadence,
    required this.samples,
  });
  final String hash;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceMetres;
  final double elevationMetres;
  final int? averageHeartRate;
  final int? maximumHeartRate;
  final int? averagePower;
  final int? maximumPower;
  final int? normalisedPower;
  final int? averageCadence;
  final List<ParsedFitSample> samples;
}

class FitImportService {
  ParsedFitActivity parse(List<int> input) {
    SessionMesg? session;
    final records = <RecordMesg>[];
    final decoder = Decode()
      ..onMesg = (mesg) {
        if (mesg.num == MesgNum.session) session = SessionMesg.fromMesg(mesg);
        if (mesg.num == MesgNum.record) {
          records.add(RecordMesg.fromMesg(mesg));
        }
      };
    decoder.read(Uint8List.fromList(input));
    if (session == null && records.isEmpty) {
      throw const FormatException(
          'No cycling activity was found in this FIT file.');
    }
    final startedAt = session?.getStartTime() ??
        records.first.getTimestamp() ??
        DateTime.now();
    final samples = records.map((record) {
      final timestamp = record.getTimestamp() ?? startedAt;
      return ParsedFitSample(
        elapsedSeconds:
            timestamp.difference(startedAt).inSeconds.clamp(0, 1 << 31),
        heartRate: record.getHeartRate(),
        power: record.getPower(),
        cadence: record.getCadence(),
        altitudeMetres: record.getEnhancedAltitude() ?? record.getAltitude(),
        distanceMetres: record.getDistance(),
      );
    }).toList();
    final lastDistance = records.isEmpty ? null : records.last.getDistance();
    final duration = session?.getTotalTimerTime()?.round() ??
        (samples.isEmpty ? 0 : samples.last.elapsedSeconds);
    return ParsedFitActivity(
      hash: sha256.convert(input).toString(),
      startedAt: startedAt,
      durationSeconds: duration,
      distanceMetres: session?.getTotalDistance() ?? lastDistance ?? 0,
      elevationMetres: (session?.getTotalAscent() ?? 0).toDouble(),
      averageHeartRate: session?.getAvgHeartRate(),
      maximumHeartRate: session?.getMaxHeartRate(),
      averagePower: session?.getAvgPower(),
      maximumPower: session?.getMaxPower(),
      normalisedPower: session?.getNormalizedPower(),
      averageCadence: session?.getAvgCadence(),
      samples: samples,
    );
  }
}
