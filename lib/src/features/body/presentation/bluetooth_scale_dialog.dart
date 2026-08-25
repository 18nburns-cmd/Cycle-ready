import 'package:cycle_ready/src/features/body/application/body_measurement_controller.dart';
import 'package:cycle_ready/src/features/body/data/bluetooth_scale_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bluetoothScaleServiceProvider =
    Provider((ref) => BluetoothScaleService());

Future<void> showBluetoothScaleDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _BluetoothScaleDialog(ref: ref),
  );
}

class _BluetoothScaleDialog extends StatefulWidget {
  const _BluetoothScaleDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_BluetoothScaleDialog> createState() => _BluetoothScaleDialogState();
}

class _BluetoothScaleDialogState extends State<_BluetoothScaleDialog> {
  ScaleCapture? capture;
  List<ScaleCandidate> candidates = const [];
  String? error;
  bool busy = false;
  bool saved = false;

  BluetoothScaleService get service =>
      widget.ref.read(bluetoothScaleServiceProvider);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Hubit Bluetooth scale'),
        content: SizedBox(
          width: 460,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .68,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Force-close AFit, stand on the scale to wake it, then '
                    'connect while the reading is stable.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Known address: $hubitScaleAddress',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (busy) ...[
                    const SizedBox(height: 18),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep standing still. CycleReady is inspecting the Bluetooth data…',
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (candidates.isNotEmpty && capture == null) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Nearby connectable devices',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Wake the scale again, then select the device that appears or has the strongest signal.',
                    ),
                    const SizedBox(height: 8),
                    ...candidates.take(12).map(
                          (candidate) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading:
                                  const Icon(Icons.monitor_weight_outlined),
                              title: Text(candidate.name),
                              subtitle: Text(
                                '${candidate.id} · signal ${candidate.rssi} dBm',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: busy ? null : () => _connect(candidate),
                            ),
                          ),
                        ),
                  ],
                  if (capture case final result?) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.bluetooth_connected),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${result.deviceName} connected',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      result.deviceId,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (result.measurement case final measurement?) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${measurement.weightKg.toStringAsFixed(1)} kg',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(saved
                          ? 'Saved to your weight history.'
                          : 'A standard Bluetooth weight measurement was received.'),
                    ] else ...[
                      const SizedBox(height: 12),
                      const Text(
                        'This device does not expose the standard weight characteristic. '
                        'The diagnostic report below can be used to add its proprietary protocol.',
                      ),
                      const SizedBox(height: 12),
                      _DiagnosticSection(
                        title: 'Services',
                        values: result.serviceIds,
                      ),
                      _DiagnosticSection(
                        title: 'Characteristics',
                        values: result.characteristicInfo,
                      ),
                      _DiagnosticSection(
                        title: 'Raw packets captured',
                        values: result.rawPackets,
                        emptyMessage:
                            'No packet arrived. Wake the scale and run the diagnostic again while standing on it.',
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _copyReport,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy diagnostic report'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (capture?.measurement != null && !saved)
            FilledButton(
              onPressed: _save,
              child: const Text('Save weight'),
            )
          else ...[
            TextButton.icon(
              onPressed: busy ? null : _findNearby,
              icon: const Icon(Icons.radar),
              label: const Text('Find nearby'),
            ),
            FilledButton.icon(
              onPressed: busy ? null : _autoConnect,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Auto connect'),
            ),
          ],
        ],
      );

  Future<void> _autoConnect() async {
    _startBusy();
    try {
      final result = await service.connectAndCapture();
      if (mounted) setState(() => capture = result);
    } catch (value) {
      _showError(value);
    } finally {
      _finishBusy();
    }
  }

  Future<void> _findNearby() async {
    _startBusy();
    try {
      final found = await service.scanNearby();
      if (!mounted) return;
      setState(() {
        candidates = found;
        if (found.isEmpty) {
          error =
              'No connectable Bluetooth devices were found. Confirm Nearby devices permission and wake the scale.';
        }
      });
    } catch (value) {
      _showError(value);
    } finally {
      _finishBusy();
    }
  }

  Future<void> _connect(ScaleCandidate candidate) async {
    _startBusy();
    try {
      final result = await service.connectCandidate(candidate);
      if (mounted) setState(() => capture = result);
    } catch (value) {
      _showError(value);
    } finally {
      _finishBusy();
    }
  }

  void _startBusy() {
    setState(() {
      busy = true;
      capture = null;
      error = null;
      saved = false;
    });
  }

  void _finishBusy() {
    if (mounted) setState(() => busy = false);
  }

  void _showError(Object value) {
    if (!mounted) return;
    setState(() {
      error = value.toString().replaceFirst('Bad state: ', '');
    });
  }

  Future<void> _save() async {
    final measurement = capture?.measurement;
    if (measurement == null) return;
    await widget.ref.read(bodyMeasurementControllerProvider).saveBluetooth(
          weightKg: measurement.weightKg,
          bodyFatPercent: measurement.bodyFatPercent,
          source: 'bluetooth:${capture!.deviceName}',
        );
    if (mounted) setState(() => saved = true);
  }

  Future<void> _copyReport() async {
    final value = capture;
    if (value == null) return;
    final report = [
      'CycleReady Bluetooth scale diagnostic',
      'Device: ${value.deviceName}',
      'ID: ${value.deviceId}',
      '',
      'Services:',
      ...value.serviceIds,
      '',
      'Characteristics:',
      ...value.characteristicInfo,
      '',
      'Raw packets:',
      ...value.rawPackets,
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth report copied.')),
      );
    }
  }
}

class _DiagnosticSection extends StatelessWidget {
  const _DiagnosticSection({
    required this.title,
    required this.values,
    this.emptyMessage = 'None reported.',
  });

  final String title;
  final List<String> values;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            SelectableText(
              values.isEmpty ? emptyMessage : values.join('\n'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}
