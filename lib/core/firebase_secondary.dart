import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class SecondaryAuth {
  static const String _appName = 'harvesthub_account_creator';

  static Future<FirebaseAuth> instance() async {
    for (final app in Firebase.apps) {
      if (app.name == _appName) return FirebaseAuth.instanceFor(app: app);
    }
    final app = await Firebase.initializeApp(
        name: _appName, options: Firebase.app().options);
    return FirebaseAuth.instanceFor(app: app);
  }
}
