import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:meta/meta.dart';
import 'package:tangent_sdk/src/core/service/app_check_service.dart';
import '../core/types/result.dart';

@immutable
class FirebaseAppCheckService implements AppCheckService {
    const FirebaseAppCheckService();

  @override
  Future<Result<void>> activate() async {
    return resultOfAsync(() async {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.appAttest,
      );
    });
  }
}
