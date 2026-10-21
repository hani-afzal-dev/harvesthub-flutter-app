import 'package:flutter/foundation.dart';

String? semanticsIdOf(Key? key) {
  if (key is ValueKey<String>) return key.value;
  return null;
}
