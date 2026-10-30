import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/push_target.dart';

final pendingPushTargetProvider = StateProvider<PushTarget?>((ref) => null);
