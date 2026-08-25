import 'package:cycle_ready/src/features/splash/domain/motivational_quotes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the quote remains consistent throughout the same day', () {
    final morning = quoteForDay(DateTime(2026, 7, 28, 7));
    final evening = quoteForDay(DateTime(2026, 7, 28, 22));
    expect(evening.text, morning.text);
    expect(evening.author, morning.author);
  });

  test('the quote rotation contains no empty entries', () {
    expect(motivationalQuotes, isNotEmpty);
    expect(
      motivationalQuotes.every(
        (quote) => quote.text.isNotEmpty && quote.author.isNotEmpty,
      ),
      isTrue,
    );
  });
}
