abstract final class Units {
  static const metresPerMile = 1609.344;
  static const feetPerMetre = 3.28084;

  static String distance(double metres, {int decimals = 1}) =>
      '${(metres / metresPerMile).toStringAsFixed(decimals)} mi';

  static String elevation(double metres) =>
      '${(metres * feetPerMetre).round()} ft';
}
