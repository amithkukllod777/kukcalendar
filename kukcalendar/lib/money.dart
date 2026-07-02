/// Minimal money formatter kept only so shared calendar code compiles. The
/// standalone Kuk Calendar shows no monetary amounts (that was a KukBook-only
/// business overlay), so a plain 2-decimal formatter is all that's needed.
class Money {
  static _LiveMoney fmt([int decimals = 2]) => _LiveMoney(decimals);
  static String format(num value) => value.toStringAsFixed(2);
}

class _LiveMoney {
  final int decimals;
  const _LiveMoney([this.decimals = 2]);
  String format(num value) => value.toStringAsFixed(decimals);
}
