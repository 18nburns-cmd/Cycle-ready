class MotivationalQuote {
  const MotivationalQuote(this.text, this.author);

  final String text;
  final String author;
}

const motivationalQuotes = <MotivationalQuote>[
  MotivationalQuote(
    'Success is the sum of small efforts, repeated day in and day out.',
    'Robert Collier',
  ),
  MotivationalQuote(
    'The journey matters as much as the destination.',
    'CycleReady',
  ),
  MotivationalQuote(
    'Train with purpose. Recover with patience. Return stronger.',
    'CycleReady',
  ),
  MotivationalQuote(
    'Consistency turns ordinary days into extraordinary progress.',
    'CycleReady',
  ),
  MotivationalQuote(
    'Every ride is a chance to become stronger than yesterday.',
    'CycleReady',
  ),
  MotivationalQuote(
    'Listen to your body, trust your training, and enjoy the road.',
    'CycleReady',
  ),
  MotivationalQuote(
    'Big goals are reached one purposeful pedal stroke at a time.',
    'CycleReady',
  ),
];

MotivationalQuote quoteForDay(DateTime day) {
  final dayNumber =
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
  return motivationalQuotes[dayNumber % motivationalQuotes.length];
}
