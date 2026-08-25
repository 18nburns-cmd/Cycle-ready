import 'dart:async';

import 'package:cycle_ready/src/features/body/domain/bluetooth_weight_parser.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const hubitScaleAddress = '03:B3:EC:93:B6:F5';

class ScaleCapture {
  const ScaleCapture({
    required this.deviceName,
    required this.deviceId,
    required this.serviceIds,
    this.characteristicInfo = const [],
    this.rawPackets = const [],
    this.measurement,
  });

  final String deviceName;
  final String deviceId;
  final List<String> serviceIds;
  final List<String> characteristicInfo;
  final List<String> rawPackets;
  final BluetoothWeightMeasurement? measurement;

  bool get usesStandardWeightService =>
      serviceIds.any((id) => id.toLowerCase().contains('181d'));
}

class ScaleCandidate {
  const ScaleCandidate({
    required this.device,
    required this.name,
    required this.id,
    required this.rssi,
    required this.advertisementPackets,
  });

  final BluetoothDevice device;
  final String name;
  final String id;
  final int rssi;
  final List<String> advertisementPackets;
}

class BluetoothScaleService {
  Future<List<ScaleCandidate>> scanNearby({
    Duration scanTimeout = const Duration(seconds: 10),
  }) async {
    await _ensureBluetoothReady();
    final nearby = <String, ScanResult>{};
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        nearby[result.device.remoteId.str] = result;
      }
    });
    try {
      await FlutterBluePlus.startScan(timeout: scanTimeout);
      await Future<void>.delayed(
          scanTimeout + const Duration(milliseconds: 300));
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
      final candidates = nearby.values
          .where((result) => result.advertisementData.connectable)
          .map(
            (result) => ScaleCandidate(
              device: result.device,
              name: _scanName(result),
              id: result.device.remoteId.str,
              rssi: result.rssi,
              advertisementPackets: _advertisementPackets(result),
            ),
          )
          .toList()
        ..sort((a, b) {
          final aLikely = _looksLikeScale(a) ? 1 : 0;
          final bLikely = _looksLikeScale(b) ? 1 : 0;
          final likely = bLikely.compareTo(aLikely);
          return likely != 0 ? likely : b.rssi.compareTo(a.rssi);
        });
      return candidates;
    } finally {
      await subscription.cancel();
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    }
  }

  Future<ScaleCapture> connectCandidate(
    ScaleCandidate candidate, {
    Duration measurementTimeout = const Duration(seconds: 20),
  }) =>
      _capture(
        candidate.device,
        measurementTimeout,
        advertisementPackets: candidate.advertisementPackets,
      );

  Future<ScaleCapture> connectAndCapture({
    Duration scanTimeout = const Duration(seconds: 15),
    Duration measurementTimeout = const Duration(seconds: 30),
  }) async {
    await _ensureBluetoothReady();

    final nearby = <ScanResult>[];
    final found = Completer<ScanResult>();
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      nearby
        ..clear()
        ..addAll(results);
      for (final result in results) {
        final id = result.device.remoteId.str.toUpperCase();
        final name =
            '${result.advertisementData.advName} ${result.device.platformName}'
                .toLowerCase();
        if (id == hubitScaleAddress || name.contains('hubit')) {
          if (!found.isCompleted) found.complete(result);
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: scanTimeout);
      final result = await found.future.timeout(
        scanTimeout + const Duration(seconds: 1),
        onTimeout: () {
          final names = nearby
              .map((item) => item.advertisementData.advName)
              .where((name) => name.isNotEmpty)
              .take(4)
              .join(', ');
          throw StateError(
            'Hubit scale was not found. Wake it by standing on it and keep '
            'AFit closed.${names.isEmpty ? '' : ' Nearby: $names'}',
          );
        },
      );
      await FlutterBluePlus.stopScan();
      return _capture(
        result.device,
        measurementTimeout,
        advertisementPackets: _advertisementPackets(result),
      );
    } finally {
      await subscription.cancel();
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    }
  }

  Future<ScaleCapture> _capture(
    BluetoothDevice device,
    Duration measurementTimeout, {
    List<String> advertisementPackets = const [],
  }) async {
    await device.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 15),
    );
    try {
      final services = await device.discoverServices();
      final serviceIds = services.map((service) => service.uuid.str).toList();
      BluetoothCharacteristic? weightCharacteristic;
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid.str.toLowerCase().contains('2a9d')) {
            weightCharacteristic = characteristic;
          }
        }
      }

      if (weightCharacteristic == null) {
        final diagnostics = await _captureProprietaryPackets(
          services,
          measurementTimeout,
          advertisementPackets,
        );
        return ScaleCapture(
          deviceName: _name(device),
          deviceId: device.remoteId.str,
          serviceIds: serviceIds,
          characteristicInfo: diagnostics.$1,
          rawPackets: diagnostics.$2,
        );
      }

      if (weightCharacteristic.properties.notify ||
          weightCharacteristic.properties.indicate) {
        await weightCharacteristic.setNotifyValue(true);
      }
      if (weightCharacteristic.properties.read) {
        final parsed =
            parseStandardWeightMeasurement(await weightCharacteristic.read());
        if (parsed != null) {
          return ScaleCapture(
            deviceName: _name(device),
            deviceId: device.remoteId.str,
            serviceIds: serviceIds,
            measurement: parsed,
          );
        }
      }

      final measurement = await weightCharacteristic.lastValueStream
          .map(parseStandardWeightMeasurement)
          .where((value) => value != null)
          .cast<BluetoothWeightMeasurement>()
          .first
          .timeout(
            measurementTimeout,
            onTimeout: () => throw StateError(
              'Connected to the scale but no stable weight was received. '
              'Stand still on it and try again.',
            ),
          );
      return ScaleCapture(
        deviceName: _name(device),
        deviceId: device.remoteId.str,
        serviceIds: serviceIds,
        measurement: measurement,
      );
    } finally {
      await device.disconnect();
    }
  }

  String _name(BluetoothDevice device) =>
      device.platformName.isEmpty ? 'Hubit scale' : device.platformName;

  Future<void> _ensureBluetoothReady() async {
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('Bluetooth Low Energy is not supported on this phone.');
    }
    final adapter = await FlutterBluePlus.adapterState
        .where((state) => state != BluetoothAdapterState.unknown)
        .first;
    if (adapter == BluetoothAdapterState.unauthorized) {
      throw StateError(
        'Allow Nearby devices for CycleReady in Android Settings, then try again.',
      );
    }
    if (adapter != BluetoothAdapterState.on) {
      throw StateError('Turn Bluetooth on, then try again.');
    }
  }

  Future<(List<String>, List<String>)> _captureProprietaryPackets(
    List<BluetoothService> services,
    Duration timeout,
    List<String> advertisements,
  ) async {
    final characteristics = <String>[];
    final packets = <String>{...advertisements};
    final subscriptions = <StreamSubscription<List<int>>>[];
    final notifying = <BluetoothCharacteristic>[];
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        final properties = characteristic.properties;
        final flags = <String>[
          if (properties.read) 'read',
          if (properties.write) 'write',
          if (properties.writeWithoutResponse) 'write-no-response',
          if (properties.notify) 'notify',
          if (properties.indicate) 'indicate',
        ];
        characteristics.add(
          '${service.uuid.str} / ${characteristic.uuid.str} '
          '[${flags.isEmpty ? 'no exposed properties' : flags.join(', ')}]',
        );
        if (properties.read) {
          try {
            final value = await characteristic.read();
            if (value.isNotEmpty) {
              packets.add(
                '${characteristic.uuid.str} read: ${formatBluetoothPacket(value)}',
              );
            }
          } catch (_) {
            // Some devices advertise read access but reject it until a
            // proprietary command is written.
          }
        }
        if (properties.notify || properties.indicate) {
          subscriptions.add(
            characteristic.onValueReceived.listen((value) {
              if (value.isNotEmpty) {
                packets.add(
                  '${characteristic.uuid.str} notify: '
                  '${formatBluetoothPacket(value)}',
                );
              }
            }),
          );
          try {
            await characteristic.setNotifyValue(true);
            notifying.add(characteristic);
          } catch (_) {
            // Retain the characteristic in the report even when subscription
            // needs an undocumented initialization command.
          }
        }
      }
    }
    if (notifying.isNotEmpty) await Future<void>.delayed(timeout);
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    for (final characteristic in notifying) {
      try {
        await characteristic.setNotifyValue(false);
      } catch (_) {}
    }
    return (characteristics, packets.toList());
  }

  static String _scanName(ScanResult result) {
    final advertised = result.advertisementData.advName.trim();
    if (advertised.isNotEmpty) return advertised;
    final platform = result.device.platformName.trim();
    return platform.isEmpty ? 'Unnamed Bluetooth device' : platform;
  }

  static bool _looksLikeScale(ScaleCandidate candidate) {
    final value = '${candidate.name} ${candidate.id}'.toLowerCase();
    return value.contains('hubit') ||
        value.contains('scale') ||
        value.contains('weight') ||
        candidate.id.toUpperCase() == hubitScaleAddress;
  }

  static List<String> _advertisementPackets(ScanResult result) {
    final packets = <String>[];
    result.advertisementData.manufacturerData.forEach((id, value) {
      if (value.isNotEmpty) {
        packets.add('manufacturer $id: ${formatBluetoothPacket(value)}');
      }
    });
    result.advertisementData.serviceData.forEach((id, value) {
      if (value.isNotEmpty) {
        packets.add('service ${id.str}: ${formatBluetoothPacket(value)}');
      }
    });
    return packets;
  }
}

String formatBluetoothPacket(List<int> value) => value
    .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
