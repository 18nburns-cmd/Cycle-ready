enum RideSetting { indoor, outdoor, flexible }

class CyclingAvailability {
  const CyclingAvailability({
    required this.weekday,
    required this.enabled,
    required this.startMinutes,
    required this.durationMinutes,
    required this.setting,
  });

  final int weekday;
  final bool enabled;
  final int startMinutes;
  final int durationMinutes;
  final RideSetting setting;

  Map<String, Object> toJson() => {
        'weekday': weekday,
        'enabled': enabled,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
        'setting': setting.name,
      };

  factory CyclingAvailability.fromJson(Map<String, dynamic> json) =>
      CyclingAvailability(
        weekday: json['weekday'] as int,
        enabled: json['enabled'] as bool? ?? false,
        startMinutes: json['startMinutes'] as int? ?? 18 * 60,
        durationMinutes: json['durationMinutes'] as int? ?? 60,
        setting: RideSetting.values.firstWhere(
          (value) => value.name == json['setting'],
          orElse: () => RideSetting.flexible,
        ),
      );

  CyclingAvailability copyWith({
    bool? enabled,
    int? startMinutes,
    int? durationMinutes,
    RideSetting? setting,
  }) =>
      CyclingAvailability(
        weekday: weekday,
        enabled: enabled ?? this.enabled,
        startMinutes: startMinutes ?? this.startMinutes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        setting: setting ?? this.setting,
      );
}

List<CyclingAvailability> defaultCyclingAvailability() => List.generate(
      7,
      (index) {
        final weekday = index + 1;
        final weekend = weekday >= DateTime.saturday;
        return CyclingAvailability(
          weekday: weekday,
          enabled: const {
            DateTime.tuesday,
            DateTime.thursday,
            DateTime.saturday,
            DateTime.sunday
          }.contains(weekday),
          startMinutes: weekend ? 9 * 60 : 18 * 60,
          durationMinutes: weekday == DateTime.saturday
              ? 180
              : weekday == DateTime.sunday
                  ? 90
                  : 60,
          setting: weekend ? RideSetting.outdoor : RideSetting.indoor,
        );
      },
    );

List<CyclingAvailability> applyEquipmentConstraints(
  Iterable<CyclingAvailability> availability, {
  required bool hasIndoorTrainer,
}) =>
    List.unmodifiable(
      availability.map(
        (slot) => !hasIndoorTrainer && slot.setting == RideSetting.indoor
            ? slot.copyWith(setting: RideSetting.flexible)
            : slot,
      ),
    );
