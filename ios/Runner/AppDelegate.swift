import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Maps SDK aborts with NSException if provideAPIKey is never called. Prefer
    // `GoogleService-Info.plist` → API_KEY; optional `Info.plist` → GMSApiKey; then
    // embedded fallback (same Firebase iOS key committed with the plist).
    let fromPlist: String? = {
      guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: path),
            let k = plist["API_KEY"] as? String else { return nil }
      let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
      return t.isEmpty ? nil : t
    }()
    let fromInfo: String? = {
      guard let k = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String else { return nil }
      let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
      return t.isEmpty ? nil : t
    }()
    let fallback =
      "AIzaSyB0Vc4-VPz83l6fQ3a_fW0dFqnrtWfq0dw"
    let apiKey = fromPlist ?? fromInfo ?? fallback
    if fromPlist == nil && fromInfo == nil {
      NSLog("Google Maps: using embedded fallback key — verify GoogleService-Info.plist is in the app target.")
    }
    GMSServices.provideAPIKey(apiKey)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
