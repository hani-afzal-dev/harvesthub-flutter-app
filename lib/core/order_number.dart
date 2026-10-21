String orderNumber(String orderId) {
  var hash = 0x811c9dc5;
  for (final unit in orderId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final digits = (hash % 1000000).toString().padLeft(6, '0');
  return '#$digits';
}
