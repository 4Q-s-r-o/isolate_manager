/// Priority of execution
enum Priority {
  /// Lowest
  low,

  /// Mid
  mid,

  /// Highest
  high;

  /// Sorted executuon
  static List<Priority> get sorted => [high, mid, low];
}
