enum Parity {
  none,
  odd,
  even,
  mark,
  space;

  static Parity? fromValue(int value) => Parity.values.elementAtOrNull(value);
}