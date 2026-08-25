import 'package:cycle_ready/src/features/weather/data/cached_weather_repository.dart';
import 'package:cycle_ready/src/features/weather/domain/ride_weather.dart';
import 'package:cycle_ready/src/features/weather/domain/weather_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 8, 25);
  WeatherForecast forecast(DateTime fetchedAt) => WeatherForecast(
        fetchedAt: fetchedAt,
        values: {
          day: RideWeather(
            at: DateTime(2026, 8, 25, 18),
            temperatureC: 17,
            precipitationMm: 0,
            precipitationProbability: 20,
            windGustKph: 25,
            weatherCode: 2,
          ),
        },
      );

  test('successful remote forecast is cached', () async {
    final store = _MemoryWeatherCache();
    final remote = _FakeWeatherRepository(forecast(day));
    final repository = CachedWeatherRepository(remote, store, now: () => day);

    final result = await repository.forecast(
      location: 'NE1 1AA',
      rideTimeMinutes: 18 * 60,
    );

    expect(result.isCached, isFalse);
    expect(store.values, isNotEmpty);
  });

  test('network failure returns recent cached forecast marked as cached',
      () async {
    final store = _MemoryWeatherCache();
    final remote = _FakeWeatherRepository(forecast(day));
    final repository = CachedWeatherRepository(
      remote,
      store,
      now: () => day.add(const Duration(hours: 8)),
    );
    await repository.forecast(
      location: 'NE1 1AA',
      rideTimeMinutes: 18 * 60,
    );
    remote.failure = StateError('offline');

    final cached = await repository.forecast(
      location: 'NE1 1AA',
      rideTimeMinutes: 18 * 60,
    );

    expect(cached.isCached, isTrue);
    expect(cached.isStaleAt(day.add(const Duration(hours: 8))), isTrue);
    expect(cached.values[day]?.temperatureC, 17);
  });

  test('cache older than 36 hours is not used for coaching', () async {
    final store = _MemoryWeatherCache();
    final remote = _FakeWeatherRepository(forecast(day));
    var now = day;
    final repository = CachedWeatherRepository(remote, store, now: () => now);
    await repository.forecast(
      location: 'NE1 1AA',
      rideTimeMinutes: 18 * 60,
    );
    now = day.add(const Duration(hours: 37));
    remote.failure = StateError('offline');

    expect(
      () => repository.forecast(
        location: 'NE1 1AA',
        rideTimeMinutes: 18 * 60,
      ),
      throwsStateError,
    );
  });
}

class _FakeWeatherRepository implements WeatherRepository {
  _FakeWeatherRepository(this.value);
  final WeatherForecast value;
  Object? failure;

  @override
  Future<WeatherForecast> forecast({
    required String location,
    required int rideTimeMinutes,
  }) async {
    if (failure != null) throw failure!;
    return value;
  }
}

class _MemoryWeatherCache implements WeatherCacheStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
