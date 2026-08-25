import 'package:cycle_ready/src/features/nutrition/application/nutrition_provider.dart';
import 'package:cycle_ready/src/features/nutrition/domain/nutrition_plan.dart';
import 'package:cycle_ready/src/features/nutrition/domain/nutrition_progress.dart';
import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(todayNutritionProvider);
    final progress = ref.watch(todayNutritionProgressProvider);
    final entries =
        ref.watch(todayNutritionEntriesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel & hydration',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Food & Drink Library',
            onPressed: () => context.push('/nutrition/library'),
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          IconButton(
            tooltip: 'Scan nutrition label',
            onPressed: () => context.push('/nutrition/scan'),
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          IconButton(
            tooltip: 'Edit daily targets',
            onPressed: () => _editTargets(context, ref, progress.target),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntry(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add intake'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _RemainingDashboard(
            progress: progress,
            onTap: () => _addEntry(
              context,
              ref,
              focus: _IntakeFocus.calories,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(
                  child: Icon(Icons.document_scanner_outlined)),
              title: const Text('Scan a nutrition label',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Photograph the packet and scale its macros to your portion.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/nutrition/scan'),
            ),
          ),
          const SizedBox(height: 12),
          _MacroProgressGrid(
            progress: progress,
            onCarbohydrateTap: () => _addEntry(
              context,
              ref,
              focus: _IntakeFocus.carbohydrate,
            ),
            onProteinTap: () => _addEntry(
              context,
              ref,
              focus: _IntakeFocus.protein,
            ),
            onFatTap: () => _addEntry(
              context,
              ref,
              focus: _IntakeFocus.fat,
            ),
            onWaterTap: () => _addEntry(
              context,
              ref,
              focus: _IntakeFocus.water,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('Today’s entries',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text('${entries.length} logged',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Nothing logged yet. Add food, supplements or water and '
                  'CycleReady will subtract it from today’s targets.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: entries
                    .map((entry) => _EntryTile(
                          entry: entry,
                          onEdit: () => _editEntry(context, ref, entry),
                          onDelete: () => ref
                              .read(nutritionEntryControllerProvider)
                              .delete(entry.id),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 24),
          _PriorityCard(plan: plan),
          const SizedBox(height: 24),
          Text('Around your ride',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Column(children: [
              _TimingTile(
                icon: Icons.schedule,
                title: 'Before',
                value: plan.preRideCarbs == 0
                    ? 'Normal meal'
                    : '${plan.preRideCarbs} g carbohydrate',
                detail: plan.preRideCarbs == 0
                    ? 'No special pre-ride fuel needed.'
                    : 'Aim for this 1–3 hours before riding.',
              ),
              const Divider(height: 1),
              _TimingTile(
                icon: Icons.directions_bike,
                title: 'During',
                value: plan.rideCarbsPerHour == 0
                    ? 'Water as needed'
                    : '${plan.rideCarbsPerHour} g carbs/hour',
                detail:
                    '${plan.rideFluidPerHour} ml fluid/hour; adjust for heat and sweat rate.',
              ),
              const Divider(height: 1),
              _TimingTile(
                icon: Icons.restore,
                title: 'After',
                value: plan.recoveryProtein == 0
                    ? 'Your next normal meal'
                    : '${plan.recoveryCarbs} g carbs + ${plan.recoveryProtein} g protein',
                detail: plan.recoveryProtein == 0
                    ? 'Keep regular meal timing.'
                    : 'A practical target within about two hours.',
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Text(
            'Targets are training guidance based on your saved weight and today’s ride. They do not account for medical conditions, climate or individual sweat losses.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _addEntry(
    BuildContext context,
    WidgetRef ref, {
    _IntakeFocus focus = _IntakeFocus.name,
  }) async {
    final library =
        ref.read(savedFoodsProvider).valueOrNull ?? const <SavedFood>[];
    final recentEntries = await ref
        .read(databaseProvider)
        .getRecentNutritionEntries()
        .then(_uniqueRecentEntries)
        .catchError((_) => <NutritionEntry>[]);
    if (!context.mounted) return;
    final label = TextEditingController();
    final calories = TextEditingController();
    final carbs = TextEditingController();
    final protein = TextEditingController();
    final fat = TextEditingController();
    final water = TextEditingController();
    var saveToLibrary = false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Add food or drink',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (library.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your library — tap to use',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: library.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final food = library[index];
                    return ActionChip(
                      avatar: const Icon(Icons.bookmark, size: 17),
                      label: Text(food.name),
                      onPressed: () {
                        label.text = food.name;
                        calories.text = _wholeOrEmpty(food.calories);
                        carbs.text = _decimalOrEmpty(food.carbohydrateGrams);
                        protein.text = _decimalOrEmpty(food.proteinGrams);
                        fat.text = _decimalOrEmpty(food.fatGrams);
                        water.text = _wholeOrEmpty(food.waterMillilitres);
                      },
                    );
                  },
                ),
              ),
            ],
            if (recentEntries.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent — tap to reuse',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentEntries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final entry = recentEntries[index];
                    return ActionChip(
                      avatar: const Icon(Icons.history, size: 17),
                      label: Text(entry.label),
                      tooltip: _nutritionSummary(entry),
                      onPressed: () {
                        label.text = entry.label;
                        calories.text = _wholeOrEmpty(entry.calories);
                        carbs.text = _decimalOrEmpty(entry.carbohydrateGrams);
                        protein.text = _decimalOrEmpty(entry.proteinGrams);
                        fat.text = _decimalOrEmpty(entry.fatGrams);
                        water.text = _wholeOrEmpty(entry.waterMillilitres);
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: label,
              autofocus: focus == _IntakeFocus.name,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Breakfast, protein shake, water…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _numberField(
                  calories,
                  'Calories',
                  'kcal',
                  autofocus: focus == _IntakeFocus.calories,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                  water,
                  'Water',
                  'ml',
                  autofocus: focus == _IntakeFocus.water,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _numberField(
                  carbs,
                  'Carbs',
                  'g',
                  autofocus: focus == _IntakeFocus.carbohydrate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(
                  protein,
                  'Protein',
                  'g',
                  autofocus: focus == _IntakeFocus.protein,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(
                  fat,
                  'Fat',
                  'g',
                  autofocus: focus == _IntakeFocus.fat,
                ),
              ),
            ]),
            StatefulBuilder(
              builder: (context, setCheckboxState) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: saveToLibrary,
                onChanged: (value) => setCheckboxState(
                  () => saveToLibrary = value ?? false,
                ),
                title: const Text('Save to Food & Drink Library'),
                subtitle:
                    const Text('Keep this serving available permanently.'),
                secondary: const Icon(Icons.bookmark_add_outlined),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  // Let TextField dependants detach from MediaQuery before the
                  // modal route is removed. Popping with the IME still attached
                  // can trip InheritedElement.debugDeactivated.
                  FocusScope.of(context).unfocus();
                  await Future<void>.delayed(const Duration(milliseconds: 250));
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('Add to today'),
              ),
            ),
          ]),
        ),
      ),
    );
    if (saved == true) {
      final entry = (
        label: label.text,
        calories: int.tryParse(calories.text) ?? 0,
        carbohydrateGrams: double.tryParse(carbs.text) ?? 0,
        proteinGrams: double.tryParse(protein.text) ?? 0,
        fatGrams: double.tryParse(fat.text) ?? 0,
        waterMillilitres: int.tryParse(water.text) ?? 0,
      );
      // Allow the closing bottom-sheet frame to finish before Drift emits its
      // updated stream. This prevents Riverpod from requesting a rebuild while
      // the navigator is still building the previous frame.
      await WidgetsBinding.instance.endOfFrame;
      try {
        await ref.read(nutritionEntryControllerProvider).add(
              label: entry.label,
              calories: entry.calories,
              carbohydrateGrams: entry.carbohydrateGrams,
              proteinGrams: entry.proteinGrams,
              fatGrams: entry.fatGrams,
              waterMillilitres: entry.waterMillilitres,
              saveToLibrary: saveToLibrary,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Intake added to today.')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('That intake could not be saved. Please try again.'),
            ),
          );
        }
      }
    }
    // showModalBottomSheet completes before its reverse route animation has
    // necessarily disposed every TextField. Keep controllers alive until then.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final controller in [label, calories, carbs, protein, fat, water]) {
      controller.dispose();
    }
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    NutritionEntry entry,
  ) async {
    final label = TextEditingController(text: entry.label);
    final calories = TextEditingController(text: '${entry.calories}');
    final carbs =
        TextEditingController(text: _decimalOrEmpty(entry.carbohydrateGrams));
    final protein =
        TextEditingController(text: _decimalOrEmpty(entry.proteinGrams));
    final fat = TextEditingController(text: _decimalOrEmpty(entry.fatGrams));
    final water = TextEditingController(text: '${entry.waterMillilitres}');
    String? nameError;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit intake'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: label,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: nameError,
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _numberField(calories, 'Calories', 'kcal')),
                const SizedBox(width: 8),
                Expanded(child: _numberField(water, 'Water', 'ml')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _numberField(carbs, 'Carbs', 'g')),
                const SizedBox(width: 8),
                Expanded(child: _numberField(protein, 'Protein', 'g')),
                const SizedBox(width: 8),
                Expanded(child: _numberField(fat, 'Fat', 'g')),
              ]),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (label.text.trim().isEmpty) {
                  setState(() => nameError = 'A name is required');
                  return;
                }
                FocusScope.of(context).unfocus();
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await WidgetsBinding.instance.endOfFrame;
      await ref.read(nutritionEntryControllerProvider).updateEntry(
            id: entry.id,
            label: label.text,
            calories: int.tryParse(calories.text) ?? 0,
            carbohydrateGrams: double.tryParse(carbs.text) ?? 0,
            proteinGrams: double.tryParse(protein.text) ?? 0,
            fatGrams: double.tryParse(fat.text) ?? 0,
            waterMillilitres: int.tryParse(water.text) ?? 0,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intake updated.')),
        );
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final controller in [label, calories, carbs, protein, fat, water]) {
      controller.dispose();
    }
  }

  Future<void> _editTargets(
    BuildContext context,
    WidgetRef ref,
    NutritionTotals current,
  ) async {
    TextEditingController value(num number) =>
        TextEditingController(text: number.round().toString());
    final calories = value(current.calories);
    final carbs = value(current.carbohydrateGrams);
    final protein = value(current.proteinGrams);
    final fat = value(current.fatGrams);
    final water = value(current.waterMillilitres);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Today’s targets'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _numberField(calories, 'Calories', 'kcal'),
            const SizedBox(height: 10),
            _numberField(carbs, 'Carbohydrate', 'g'),
            const SizedBox(height: 10),
            _numberField(protein, 'Protein', 'g'),
            const SizedBox(height: 10),
            _numberField(fat, 'Fat', 'g'),
            const SizedBox(height: 10),
            _numberField(water, 'Water', 'ml'),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () async {
                FocusScope.of(context).unfocus();
                await Future<void>.delayed(const Duration(milliseconds: 250));
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Save targets')),
        ],
      ),
    );
    if (saved == true) {
      final target = NutritionTotals(
        calories: int.tryParse(calories.text) ?? current.calories,
        carbohydrateGrams:
            double.tryParse(carbs.text) ?? current.carbohydrateGrams,
        proteinGrams: double.tryParse(protein.text) ?? current.proteinGrams,
        fatGrams: double.tryParse(fat.text) ?? current.fatGrams,
        waterMillilitres: int.tryParse(water.text) ?? current.waterMillilitres,
      );
      await WidgetsBinding.instance.endOfFrame;
      try {
        await ref.read(nutritionEntryControllerProvider).saveTarget(target);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Today’s targets updated.')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Those targets could not be saved. Please try again.'),
            ),
          );
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final controller in [calories, carbs, protein, fat, water]) {
      controller.dispose();
    }
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String suffix, {
    bool autofocus = false,
  }) =>
      TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
      );

  List<NutritionEntry> _uniqueRecentEntries(
    List<NutritionEntry> entries,
  ) {
    final seen = <String>{};
    final unique = <NutritionEntry>[];
    for (final entry in entries) {
      final key = [
        entry.label.trim().toLowerCase(),
        entry.calories,
        entry.carbohydrateGrams,
        entry.proteinGrams,
        entry.fatGrams,
        entry.waterMillilitres,
      ].join('|');
      if (seen.add(key)) unique.add(entry);
      if (unique.length == 6) break;
    }
    return unique;
  }

  String _wholeOrEmpty(int value) => value == 0 ? '' : value.toString();

  String _decimalOrEmpty(double value) {
    if (value == 0) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  String _nutritionSummary(NutritionEntry entry) {
    final values = <String>[
      if (entry.calories > 0) '${entry.calories} kcal',
      if (entry.carbohydrateGrams > 0)
        '${_decimalOrEmpty(entry.carbohydrateGrams)} g carbs',
      if (entry.proteinGrams > 0)
        '${_decimalOrEmpty(entry.proteinGrams)} g protein',
      if (entry.fatGrams > 0) '${_decimalOrEmpty(entry.fatGrams)} g fat',
      if (entry.waterMillilitres > 0) '${entry.waterMillilitres} ml water',
    ];
    return values.isEmpty ? 'No nutrient values' : values.join(' · ');
  }
}

enum _IntakeFocus { name, calories, carbohydrate, protein, fat, water }

class _RemainingDashboard extends StatelessWidget {
  const _RemainingDashboard({
    required this.progress,
    required this.onTap,
  });
  final NutritionProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = progress.caloriesRemaining;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.local_fire_department_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remaining >= 0
                          ? '$remaining kcal left'
                          : '${-remaining} kcal over',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${progress.consumed.calories} of '
                      '${progress.target.calories} kcal consumed',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline, size: 20),
            ]),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.fraction(
                progress.consumed.calories.toDouble(),
                progress.target.calories.toDouble(),
              ),
              minHeight: 11,
              borderRadius: BorderRadius.circular(11),
              color: remaining < 0
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ]),
        ),
      ),
    );
  }
}

class _MacroProgressGrid extends StatelessWidget {
  const _MacroProgressGrid({
    required this.progress,
    required this.onCarbohydrateTap,
    required this.onProteinTap,
    required this.onFatTap,
    required this.onWaterTap,
  });
  final NutritionProgress progress;
  final VoidCallback onCarbohydrateTap;
  final VoidCallback onProteinTap;
  final VoidCallback onFatTap;
  final VoidCallback onWaterTap;

  @override
  Widget build(BuildContext context) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.55,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          _RemainingCard(
            label: 'CARBOHYDRATE',
            remaining: progress.carbohydrateRemaining,
            consumed: progress.consumed.carbohydrateGrams,
            target: progress.target.carbohydrateGrams,
            suffix: 'g',
            icon: Icons.bakery_dining_outlined,
            onTap: onCarbohydrateTap,
          ),
          _RemainingCard(
            label: 'PROTEIN',
            remaining: progress.proteinRemaining,
            consumed: progress.consumed.proteinGrams,
            target: progress.target.proteinGrams,
            suffix: 'g',
            icon: Icons.egg_alt_outlined,
            onTap: onProteinTap,
          ),
          _RemainingCard(
            label: 'FAT',
            remaining: progress.fatRemaining,
            consumed: progress.consumed.fatGrams,
            target: progress.target.fatGrams,
            suffix: 'g',
            icon: Icons.opacity_outlined,
            onTap: onFatTap,
          ),
          _RemainingCard(
            label: 'WATER',
            remaining: progress.waterRemaining.toDouble(),
            consumed: progress.consumed.waterMillilitres.toDouble(),
            target: progress.target.waterMillilitres.toDouble(),
            suffix: 'ml',
            icon: Icons.water_drop_outlined,
            onTap: onWaterTap,
          ),
        ],
      );
}

class _RemainingCard extends StatelessWidget {
  const _RemainingCard({
    required this.label,
    required this.remaining,
    required this.consumed,
    required this.target,
    required this.suffix,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final double remaining;
  final double consumed;
  final double target;
  final String suffix;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(letterSpacing: .7)),
                  const Spacer(),
                  const Icon(Icons.add_circle_outline, size: 16),
                ]),
                const Spacer(),
                Text(
                  remaining >= 0
                      ? '${remaining.round()} $suffix left'
                      : '${(-remaining).round()} $suffix over',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: target <= 0 ? 0 : (consumed / target).clamp(0, 1),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 4),
                Text(
                  '${consumed.round()} / ${target.round()} $suffix',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });
  final NutritionEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          child: Icon(entry.waterMillilitres > 0 && entry.calories == 0
              ? Icons.water_drop_outlined
              : Icons.restaurant_outlined),
        ),
        title: Text(entry.label,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${entry.calories} kcal · ${entry.carbohydrateGrams.round()}g carbs '
          '· ${entry.proteinGrams.round()}g protein · '
          '${entry.fatGrams.round()}g fat'
          '${entry.waterMillilitres > 0 ? ' · ${entry.waterMillilitres}ml water' : ''}',
        ),
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit entry',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete entry',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      );
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.plan});
  final NutritionPlan plan;

  @override
  Widget build(BuildContext context) {
    final title = switch (plan.priority) {
      FuelPriority.recovery => 'Fuel a lighter day',
      FuelPriority.steady => 'Support today’s training',
      FuelPriority.demanding => 'High-fuel day',
    };
    final icon = switch (plan.priority) {
      FuelPriority.recovery => Icons.spa_outlined,
      FuelPriority.steady => Icons.energy_savings_leaf_outlined,
      FuelPriority.demanding => Icons.bolt,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(plan.explanation),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TimingTile extends StatelessWidget {
  const _TimingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text('$title · $value',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail),
      );
}
