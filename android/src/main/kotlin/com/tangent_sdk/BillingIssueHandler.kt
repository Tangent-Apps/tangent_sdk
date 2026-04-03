package com.tangent_sdk

import io.flutter.plugin.common.MethodChannel

class BillingIssueHandler {

    /// Android: Client-side billing issue detection is limited.
    /// Google's InAppMessages API handles grace period UI automatically.
    /// For state detection, server-side RTDN (Real-Time Developer Notifications) is recommended.
    /// Returns "normal" state and management URL as a baseline.
    fun checkBillingIssue(result: MethodChannel.Result) {
        result.success(
            mapOf(
                "state" to "normal",
                "managementURL" to "https://play.google.com/store/account/subscriptions"
            )
        )
    }
}
