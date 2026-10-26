import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerTabs {
  static const int home = 0;
  static const int wishlist = 1;
  static const int cart = 2;
  static const int orders = 3;
  static const int profile = 4;
}

final customerTabRequestProvider = StateProvider<int?>((ref) => null);
