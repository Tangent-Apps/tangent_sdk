import 'dart:developer';
import 'package:in_app_review/in_app_review.dart';

class AppReviewService {
  final InAppReview _inAppReview = InAppReview.instance;

  Future<void> requestReview() async {
    if (await _inAppReview.isAvailable()) {
      await _inAppReview.requestReview();
    } else {
      log('App Review is not available');
    }
  }

  Future<bool> isAvailable() async {
    return await _inAppReview.isAvailable();
  }

  Future<void> openStoreListing({String? appStoreId}) async {
    await _inAppReview.openStoreListing(appStoreId: appStoreId);
  }
}
