import 'package:cycle_ready/src/features/nutrition/application/nutrition_provider.dart';
import 'package:cycle_ready/src/features/nutrition/data/nutrition_label_scanner.dart';
import 'package:cycle_ready/src/features/nutrition/domain/nutrition_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class NutritionLabelScannerScreen extends ConsumerStatefulWidget {
  const NutritionLabelScannerScreen({super.key});

  @override
  ConsumerState<NutritionLabelScannerScreen> createState() =>
      _NutritionLabelScannerScreenState();
}

class _NutritionLabelScannerScreenState
    extends ConsumerState<NutritionLabelScannerScreen> {
  final _name = TextEditingController();
  final _reference = TextEditingController(text: '100');
  final _portion = TextEditingController(text: '100');
  final _calories = TextEditingController();
  final _carbs = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  bool _scanning = false;
  bool _hasScan = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _reference,
      _portion,
      _calories,
      _carbs,
      _protein,
      _fat,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 90,
      maxWidth: 2200,
    );
    if (image == null || !mounted) return;
    setState(() => _scanning = true);
    try {
      final label = await NutritionLabelScanner().scan(image.path);
      if (!mounted) return;
      _reference.text = _format(label.referenceGrams);
      _portion.text = label.referenceGrams == 1 ? '1' : '100';
      _calories.text = _format(label.calories);
      _carbs.text = _format(label.carbohydrateGrams);
      _protein.text = _format(label.proteinGrams);
      _fat.text = _format(label.fatGrams);
      setState(() => _hasScan = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The label could not be read. Try a clearer photo.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  NutritionLabel get _label => NutritionLabel(
        name: _name.text.trim(),
        referenceGrams: double.tryParse(_reference.text) ?? 100,
        calories: double.tryParse(_calories.text) ?? 0,
        carbohydrateGrams: double.tryParse(_carbs.text) ?? 0,
        proteinGrams: double.tryParse(_protein.text) ?? 0,
        fatGrams: double.tryParse(_fat.text) ?? 0,
      );

  @override
  Widget build(BuildContext context) {
    final portion = double.tryParse(_portion.text) ?? 0;
    final scaled = _label.scaledTo(portion);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan nutrition label')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                const Icon(Icons.document_scanner_outlined, size: 42),
                const SizedBox(height: 10),
                const Text(
                  'Photograph the nutrition table straight-on in good light.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _scanning ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take photo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _scanning ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ]),
                if (_scanning) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Reading nutrition values…'),
                ],
              ]),
            ),
          ),
          if (_hasScan) ...[
            const SizedBox(height: 16),
            Text('Check the label values',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'OCR can make mistakes, so correct anything that does not match the packet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Food name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_reference, 'Label is per', 'g')),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _portion,
                  'Amount eaten',
                  'g',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_calories, 'Calories', 'kcal')),
              const SizedBox(width: 8),
              Expanded(child: _field(_carbs, 'Carbs', 'g')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_protein, 'Protein', 'g')),
              const SizedBox(width: 8),
              Expanded(child: _field(_fat, 'Fat', 'g')),
            ]),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your ${_format(portion)} g portion',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(
                      '${scaled.calories.round()} kcal  •  '
                      '${scaled.carbohydrateGrams.toStringAsFixed(1)} g carbs  •  '
                      '${scaled.proteinGrams.toStringAsFixed(1)} g protein  •  '
                      '${scaled.fatGrams.toStringAsFixed(1)} g fat',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: portion <= 0 ? null : () => _save(scaled),
              icon: const Icon(Icons.add_task),
              label: const Text('Add portion to today'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save(NutritionLabel scaled) async {
    if (scaled.name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Give this food a name before saving it.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await ref.read(nutritionEntryControllerProvider).add(
          label: scaled.name,
          calories: scaled.calories.round(),
          carbohydrateGrams: scaled.carbohydrateGrams,
          proteinGrams: scaled.proteinGrams,
          fatGrams: scaled.fatGrams,
          waterMillilitres: 0,
          saveToLibrary: true,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${scaled.name} added to today and saved in your library.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String suffix, {
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged ?? (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
      );
}

String _format(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
