import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Maps SDK requires provideAPIKey before any map view. Use the dedicated iOS Maps key
    // (Info.plist → GMSApiKey) first so tiles work when that key is restricted to Maps SDK
    // for iOS only. Firebase keeps using GoogleService-Info.plist → API_KEY separately.
    let mapsKeyFromInfo: String? = {
      guard let k = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String else { return nil }
      let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
      return t.isEmpty ? nil : t
    }()
    let mapsKeyFromFirebasePlist: String? = {
      guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: path),
            let k = plist["API_KEY"] as? String else { return nil }
      let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
      return t.isEmpty ? nil : t
    }()
    let fallback = "AIzaSyB0Vc4-VPz83l6fQ3a_fW0dFqnrtWfq0dw"
    let apiKey = mapsKeyFromInfo ?? mapsKeyFromFirebasePlist ?? fallback
    if mapsKeyFromInfo == nil {
      NSLog("Google Maps: GMSApiKey not set in Info.plist — using GoogleService-Info API_KEY or fallback.")
    }
    GMSServices.provideAPIKey(apiKey)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
