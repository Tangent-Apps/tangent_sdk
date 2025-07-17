import 'package:flutter/services.dart' as flutter;
import 'package:purchases_flutter/errors.dart';

import '../enum/purchase_failure_code.dart';
import '../exceptions/tangent_sdk_exception.dart';

class PurchaseErrorHelper {
  static PurchaseException getAppropriateException({
    required PurchasesErrorCode errorCode,
    required dynamic originalError,
  }) {
    final e = originalError as flutter.PlatformException;
    switch (errorCode) {
      case PurchasesErrorCode.purchaseCancelledError:
        return PurchaseException(
          'Purchase cancelled by user',
          originalError: e,
          code: PurchaseFailureCode.userCancelled,
        );
      case PurchasesErrorCode.receiptAlreadyInUseError:
        return PurchaseException('Product already owned', originalError: e, code: PurchaseFailureCode.alreadyOwned);
      case PurchasesErrorCode.networkError:
        return PurchaseException('Network error', originalError: e, code: PurchaseFailureCode.network);
      default:
        return PurchaseException('Purchase failed', originalError: e, code: PurchaseFailureCode.unknown);
    }
  }
}
