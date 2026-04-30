import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';

const _tag = 'Facebook';

class FacebookService {
  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  Future<void> initialize() async {
    await _facebookAppEvents.setAutoLogAppEventsEnabled(true);
    await _facebookAppEvents.setAdvertiserTracking(enabled: true);
    AppLogger.info('Facebook App Events initialized (auto-log enabled)', tag: _tag);
  }
}
