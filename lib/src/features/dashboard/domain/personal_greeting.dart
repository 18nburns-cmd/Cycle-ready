String personalGreeting(DateTime time, {String name = 'Neil'}) {
  final greeting = time.hour < 12
      ? 'Good morning'
      : time.hour < 18
          ? 'Good afternoon'
          : 'Good evening';
  return '$greeting, $name';
}
