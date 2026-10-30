/// Compares app versions like `0.2.0` or `1.4.2+7`: the numbers before any
/// `+build` or `-tag`, left to right, a missing number counting as 0.
List<int>? _parts(String version) {
  final core = version.split(RegExp('[+-]')).first.trim();
  final parts = core.split('.');
  if (parts.isEmpty || parts.length > 3) return null;
  final numbers = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    numbers.add(n);
  }
  while (numbers.length < 3) {
    numbers.add(0);
  }
  return numbers;
}

/// True only when both versions can be read and [installed] is older than [minimum].
/// A version we cannot read never blocks anyone.
bool isOlderThan(String installed, String minimum) {
  final a = _parts(installed);
  final b = _parts(minimum);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return false;
}
