import Flutter
import UIKit

public class TangentSdkPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.tangent_sdk/billing_issue",
            binaryMessenger: registrar.messenger()
        )
        let instance = TangentSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkBillingIssue":
            if #available(iOS 15.0, *) {
                let handler = BillingIssueHandler()
                handler.checkBillingIssue(result: result)
            } else {
                result([
                    "state": "normal",
                    "managementURL": "https://apps.apple.com/account/subscriptions",
                ])
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
