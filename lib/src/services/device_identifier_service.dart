import 'dart:io';

import 'package:adjust_sdk/adjust.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tangent_sdk/src/core/utils/app_logger.dart';

/// Service responsible for collecting device identifiers required for
/// RevenueCat-Adjust integration.
///
/// This service collects the following identifiers:
/// - Adjust ID ($adjustId) - Required for attribution
/// - IDFA ($idfa) - iOS Advertising Identifier
/// - GPS AdId ($gpsAdId) - Google Advertising ID
/// - IDFV ($idfv) - iOS Vendor Identifier
///
/// These identifiers are set as subscriber attributes in RevenueCat to enable
/// precise revenue tracking through Adjust attribution.
///
/// Reference: https://www.revenuecat.com/docs/integrations/attribution/adjust
@immutable
class DeviceIdentifierService {
  static const String _tag = 'DeviceIdentifiers';

  const DeviceIdentifierService();

  /// Collects all available device identifiers and sets them as RevenueCat subscriber attributes.
  ///
  /// This method should be called after both Adjust and RevenueCat SDKs are initialized,
  /// but before the first purchase is made.
  ///
  /// Returns a Map of successfully collected identifiers for logging purposes.
  Future<Map<String, String>> collectAndSetIdentifiers() async {
    final identifiers = <String, String>{};

    try {
      AppLogger.info('Starting device identifier collection', tag: _tag);

      // Collect Adjust ID (Required)
      final adjustId = await _collectAdjustId();
      if (adjustId != null) {
        identifiers['\$adjustId'] = adjustId;
        AppLogger.info('Try to set Adjust ID: $adjustId', tag: _tag);
        await Purchases.setAdjustID(adjustId);
        AppLogger.info('Set Adjust ID: $adjustId', tag: _tag);
      } else {
        AppLogger.warning('Adjust ID not available', tag: _tag);
      }

      // Collect platform-specific advertising identifiers
      if (Platform.isIOS) {
        await _collectIOSIdentifiers(identifiers);
      } else if (Platform.isAndroid) {
        await _collectAndroidIdentifiers(identifiers);
      }

      // Log collection summary
      AppLogger.info('Collected ${identifiers.length} identifiers: ${identifiers.keys.join(", ")}', tag: _tag);

      return identifiers;
    } catch (e) {
      AppLogger.error('Error collecting device identifiers', error: e, tag: _tag);
      return identifiers;
    }
  }

  /// Collect Adjust ID from Adjust SDK
  Future<String?> _collectAdjustId() async {
    try {
      AppLogger.info('Collect Adjust ID');
      final adid = await Adjust.getAdid();
      AppLogger.info('Collected Adjust ID');
      return adid;
    } catch (e) {
      AppLogger.error('Failed to collect Adjust ID', error: e, tag: _tag);
      return null;
    }
  }

  /// Collect iOS-specific identifiers (IDFA and IDFV)
  Future<void> _collectIOSIdentifiers(Map<String, String> identifiers) async {
    try {
      // Collect IDFA (iOS Advertising Identifier)
      AppLogger.info('Collected: Idfa');
      final idfa = await Adjust.getIdfa();
      if (idfa != null && idfa.isNotEmpty && idfa != '00000000-0000-0000-0000-000000000000') {
        identifiers['\$idfa'] = idfa;
        await Purchases.setAttributes({'\$idfa': idfa});
        AppLogger.info('Set IDFA: $idfa', tag: _tag);
      } else {
        AppLogger.warning('IDFA not available or user opted out', tag: _tag);
      }

      // Collect IDFV (iOS Vendor Identifier)
      AppLogger.info('Collected: Idfv');
      final idfv = await Adjust.getIdfv();
      if (idfv != null && idfv.isNotEmpty) {
        identifiers['\$idfv'] = idfv;
        await Purchases.setAttributes({'\$idfv': idfv});
        AppLogger.info('Set IDFV: $idfv', tag: _tag);
      } else {
        AppLogger.warning('IDFV not available', tag: _tag);
      }
    } catch (e) {
      AppLogger.error('Failed to collect iOS identifiers', error: e, tag: _tag);
    }
  }

  /// Collect Android-specific identifiers (GPS AdId)
  Future<void> _collectAndroidIdentifiers(Map<String, String> identifiers) async {
    try {
      // Collect GPS AdId (Google Advertising ID)
      // Note: On Android, the Google Play Services Advertising ID is collected by Adjust
      // and transmitted automatically. We use the Adjust ADID here as it's the primary identifier.
      final gpsAdId = await Adjust.getAdid();

      if (gpsAdId != null && gpsAdId.isNotEmpty) {
        identifiers['\$gpsAdId'] = gpsAdId;
        await Purchases.setAttributes({'\$gpsAdId': gpsAdId});
        AppLogger.info('Set GPS AdId: $gpsAdId', tag: _tag);
      } else {
        AppLogger.warning('GPS AdId not available', tag: _tag);
      }
    } catch (e) {
      AppLogger.error('Failed to collect Android identifiers', error: e, tag: _tag);
    }
  }

  /// Updates device identifiers.
  ///
  /// This can be called periodically or when identifiers become available
  /// (e.g., after ATT authorization on iOS).
  Future<void> updateIdentifiers() async {
    await collectAndSetIdentifiers();
  }
}
