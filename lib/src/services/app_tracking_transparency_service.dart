import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class AppTrackingTransparencyService {
  Future<void> init() async {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined || status == TrackingStatus.denied || status == TrackingStatus.restricted) {
      await Future.delayed(const Duration(milliseconds: 100));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }

  Future<TrackingStatus> getTrackingStatus() async {
    return await AppTrackingTransparency.trackingAuthorizationStatus;
  }

  Future<String?> getAdvertisingIdentifier() async {
    return await AppTrackingTransparency.getAdvertisingIdentifier();
  }
}
