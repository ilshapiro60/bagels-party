import Flutter
import GooglePlaces
import CoreLocation

/// MethodChannel bridge for the native Google Places SDK (New) — vet clinic Nearby Search.
class NativePlacesPlugin: NSObject, FlutterPlugin {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.pawparty.paw_party/places",
            binaryMessenger: registrar.messenger()
        )
        let instance = NativePlacesPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "searchNearbyVeterinaryCare":
            searchNearby(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func searchNearby(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lat = args["latitude"] as? Double,
              let lng = args["longitude"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "latitude and longitude are required", details: nil))
            return
        }
        let radius = args["radiusMeters"] as? Double ?? 8000.0
        let maxResults = args["maxResultCount"] as? Int ?? 20

        let center = CLLocationCoordinate2DMake(lat, lng)
        let restriction = GMSPlaceCircularLocationOption(center, radius)

        let properties = [
            GMSPlaceProperty.placeID,
            GMSPlaceProperty.name,
            GMSPlaceProperty.formattedAddress,
            GMSPlaceProperty.coordinate,
        ].map { $0.rawValue }

        let request = GMSPlaceSearchNearbyRequest(
            locationRestriction: restriction,
            placeProperties: properties
        )
        request.includedTypes = ["veterinary_care"]
        request.maxResultCount = maxResults
        request.rankPreference = .distance

        GMSPlacesClient.shared().searchNearby(with: request) { places, error in
            if let error = error {
                result(FlutterError(code: "PLACES_ERROR", message: error.localizedDescription, details: nil))
                return
            }
            guard let places = places else {
                result([Any]())
                return
            }
            let mapped: [[String: Any]] = places.compactMap { place in
                guard let placeId = place.placeID, !placeId.isEmpty else { return nil }
                let name = place.name ?? ""
                guard !name.isEmpty else { return nil }
                let coord = place.coordinate
                guard CLLocationCoordinate2DIsValid(coord) else { return nil }
                return [
                    "placeId": placeId,
                    "name": name,
                    "address": place.formattedAddress ?? "",
                    "latitude": coord.latitude,
                    "longitude": coord.longitude,
                ]
            }
            result(mapped)
        }
    }
}
