import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/service/app_check_service.dart';

import 'package:tangent_sdk/src/core/types/result.dart';

@immutable
class FirebaseAppCheckService implements AppCheckService {
  const FirebaseAppCheckService();

  @override
  Future<Result<void>> activate() async {
    return resultOfAsync(() async {
      // ignore: deprecated_member_use
      await FirebaseAppCheck.instance.activate(
        // ignore: deprecated_member_use
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
        // ignore: deprecated_member_use
        androidProvider: AndroidProvider.debug,
        // ignore: deprecated_member_use
        appleProvider: AppleProvider.appAttest,
      );
    });
  }
}
