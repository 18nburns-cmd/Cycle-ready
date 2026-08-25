import 'package:cycle_ready/src/features/athlete/application/athlete_profile_controller.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AthleteSettingsScreen extends ConsumerStatefulWidget {
  const AthleteSettingsScreen({super.key});
  @override
  ConsumerState<AthleteSettingsScreen> createState() =>
      _AthleteSettingsScreenState();
}

class _AthleteSettingsScreenState extends ConsumerState<AthleteSettingsScreen> {
  final athleteName = TextEditingController();
  final age = TextEditingController();
  final height = TextEditingController();
  final ftp = TextEditingController();
  final thresholdHr = TextEditingController();
  final maxHr = TextEditingController();
  final restingHr = TextEditingController();
  final weight = TextEditingController();
  final weeklyLoad = TextEditingController();
  final bikeDetails = TextEditingController();
  final equipment = TextEditingController();
  final nutritionPreferences = TextEditingController();
  final injuryHistory = TextEditingController();
  final trainingLocation = TextEditingController();
  String experienceLevel = 'intermediate';
  bool hasPowerMeter = true;
  bool hasIndoorTrainer = true;
  int preferredRideTimeMinutes = 18 * 60;
  String ridingSafetyProfile = 'balanced';
  bool loaded = false;

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      loaded = true;
      ref.read(athleteProfileControllerProvider).load().then((value) {
        if (!mounted) return;
        setState(() {
          athleteName.text = value.name;
          age.text = value.age?.toString() ?? '';
          height.text = value.heightCm?.toStringAsFixed(0) ?? '';
          ftp.text = '${value.ftp}';
          thresholdHr.text = value.thresholdHeartRate?.toString() ?? '';
          maxHr.text = '${value.maximumHeartRate}';
          restingHr.text = '${value.restingHeartRate}';
          weight.text = '${value.weightKg}';
          weeklyLoad.text = '${value.weeklyLoadTarget}';
          experienceLevel = value.experienceLevel;
          bikeDetails.text = value.bikeDetails;
          equipment.text = value.equipment;
          hasPowerMeter = value.hasPowerMeter;
          hasIndoorTrainer = value.hasIndoorTrainer;
          preferredRideTimeMinutes = value.preferredRideTimeMinutes;
          nutritionPreferences.text = value.nutritionPreferences;
          injuryHistory.text = value.injuryHistory;
          trainingLocation.text = value.trainingLocation;
          ridingSafetyProfile = value.ridingSafetyProfile;
        });
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Athlete settings')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text(
          'Your profile is the foundation for readiness, zones, workout selection and coaching explanations.',
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.query_stats),
            title: const Text('Calculated FTP'),
            subtitle:
                const Text('Estimate FTP from the last eight weeks of rides.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/ftp-estimate'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: const Text('Body & weight'),
            subtitle: const Text(
                'Health Connect history, trends, manual entry and AFit CSV.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/body'),
          ),
        ),
        const SizedBox(height: 12),
        Text('About you', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _textField(athleteName, 'Name'),
        _field(age, 'Age', 'years'),
        _field(height, 'Height', 'cm', decimal: true),
        DropdownButtonFormField<String>(
          initialValue: experienceLevel,
          decoration: const InputDecoration(
            labelText: 'Cycling experience',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
            DropdownMenuItem(
              value: 'intermediate',
              child: Text('Intermediate'),
            ),
            DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => experienceLevel = value);
          },
        ),
        const SizedBox(height: 20),
        Text('Physiology', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _field(ftp, 'FTP', 'watts'),
        _field(thresholdHr, 'Threshold heart rate', 'bpm'),
        _field(maxHr, 'Maximum heart rate', 'bpm'),
        _field(restingHr, 'Resting heart rate', 'bpm'),
        _field(weight, 'Weight', 'kg', decimal: true),
        _field(weeklyLoad, 'Weekly load target', 'points'),
        const SizedBox(height: 8),
        Text('Bike and training setup',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _textField(bikeDetails, 'Bike details'),
        _textArea(
          equipment,
          'Other equipment',
          'For example: cadence sensor, heart-rate strap, dumbbells',
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Power meter available'),
          subtitle: const Text('Allows power-targeted outdoor workouts.'),
          value: hasPowerMeter,
          onChanged: (value) => setState(() => hasPowerMeter = value),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Indoor smart trainer available'),
          subtitle: const Text(
            'If disabled, CycleReady will not require an indoor-only session.',
          ),
          value: hasIndoorTrainer,
          onChanged: (value) => setState(() => hasIndoorTrainer = value),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Preferred ride time'),
          subtitle: Text(_formatTime(preferredRideTimeMinutes)),
          trailing: const Icon(Icons.schedule),
          onTap: _choosePreferredRideTime,
        ),
        _textField(trainingLocation, 'Outdoor training location or postcode'),
        DropdownButtonFormField<String>(
          initialValue: ridingSafetyProfile,
          decoration: const InputDecoration(
            labelText: 'Outdoor riding safety',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'cautious',
              child: Text('Cautious · move indoors sooner'),
            ),
            DropdownMenuItem(
              value: 'balanced',
              child: Text('Balanced'),
            ),
            DropdownMenuItem(
              value: 'resilient',
              child: Text('Resilient · tolerate tougher weather'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => ridingSafetyProfile = value);
          },
        ),
        const SizedBox(height: 8),
        Text('Coaching considerations',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _textArea(
          nutritionPreferences,
          'Nutrition preferences',
          'Dietary needs, foods you avoid, or preferred ride fuel',
        ),
        _textArea(
          injuryHistory,
          'Injury or discomfort history',
          'Anything the coach should protect or monitor',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save settings')),
      ]),
    );
  }

  Widget _field(TextEditingController controller, String label, String suffix,
          {bool decimal = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(
              labelText: label,
              suffixText: suffix,
              border: const OutlineInputBorder()),
        ),
      );

  Widget _textArea(
    TextEditingController controller,
    String label,
    String hint,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Future<void> _choosePreferredRideTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferredRideTimeMinutes ~/ 60,
        minute: preferredRideTimeMinutes % 60,
      ),
    );
    if (selected == null || !mounted) return;
    setState(
        () => preferredRideTimeMinutes = selected.hour * 60 + selected.minute);
  }

  String _formatTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  Widget _textField(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Future<void> _save() async {
    final parsedAge = int.tryParse(age.text);
    final parsedHeight = double.tryParse(height.text);
    final parsedThresholdHr = int.tryParse(thresholdHr.text);
    if (athleteName.text.trim().isEmpty ||
        (parsedAge != null && (parsedAge < 13 || parsedAge > 100)) ||
        (parsedHeight != null && (parsedHeight < 120 || parsedHeight > 230)) ||
        (parsedThresholdHr != null &&
            (parsedThresholdHr < 80 || parsedThresholdHr > 220))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check the highlighted profile values.')),
      );
      return;
    }
    final workoutsRefreshed =
        await ref.read(athleteProfileControllerProvider).save(
              AthleteProfile(
                name: athleteName.text.trim(),
                age: parsedAge,
                heightCm: parsedHeight,
                experienceLevel: experienceLevel,
                ftp: int.tryParse(ftp.text) ?? 200,
                thresholdHeartRate: parsedThresholdHr,
                maximumHeartRate: int.tryParse(maxHr.text) ?? 190,
                restingHeartRate: int.tryParse(restingHr.text) ?? 50,
                weightKg: double.tryParse(weight.text) ?? 70,
                weeklyLoadTarget: int.tryParse(weeklyLoad.text) ?? 350,
                bikeDetails: bikeDetails.text.trim(),
                equipment: equipment.text.trim(),
                hasPowerMeter: hasPowerMeter,
                hasIndoorTrainer: hasIndoorTrainer,
                preferredRideTimeMinutes: preferredRideTimeMinutes,
                nutritionPreferences: nutritionPreferences.text.trim(),
                injuryHistory: injuryHistory.text.trim(),
                trainingLocation: trainingLocation.text.trim(),
                ridingSafetyProfile: ridingSafetyProfile,
              ),
            );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            workoutsRefreshed
                ? 'Settings saved. Future adaptive workouts now use your new FTP.'
                : 'Athlete settings saved.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    athleteName.dispose();
    age.dispose();
    height.dispose();
    ftp.dispose();
    thresholdHr.dispose();
    maxHr.dispose();
    restingHr.dispose();
    weight.dispose();
    weeklyLoad.dispose();
    bikeDetails.dispose();
    equipment.dispose();
    nutritionPreferences.dispose();
    injuryHistory.dispose();
    trainingLocation.dispose();
    super.dispose();
  }
}
