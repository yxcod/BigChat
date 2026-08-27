import Flutter
import MapKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nearbyPlacesChannel: FlutterMethodChannel?
  private var baiduSetupChannel: FlutterMethodChannel?
  private var nearbyPlacesSearch: MKLocalSearch?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.yxcod.bigchat/nearby_places",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "nearbyPlaces" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.loadNearbyPlaces(call: call, result: result)
    }
    nearbyPlacesChannel = channel

    let setupChannel = FlutterMethodChannel(
      name: "com.yxcod.bigchat/baidu_lbs_setup",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    setupChannel.setMethodCallHandler { call, result in
      guard call.method == "getApiKey" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let apiKey = Bundle.main.object(forInfoDictionaryKey: "BaiduMapAK") as? String ?? ""
      result(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    baiduSetupChannel = setupChannel
  }

  private func loadNearbyPlaces(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 14.0, *) else {
      result([])
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let latitude = arguments["latitude"] as? Double,
      let longitude = arguments["longitude"] as? Double
    else {
      result(FlutterError(code: "invalid_coordinates", message: "Invalid coordinates", details: nil))
      return
    }
    let requestedRadius = arguments["radiusMeters"] as? Double ?? 3000
    let radius = min(max(requestedRadius, 100), MKLocalPointsOfInterestRequest.maxRadius)
    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: radius)
    let search = MKLocalSearch(request: request)
    nearbyPlacesSearch?.cancel()
    nearbyPlacesSearch = search
    let origin = CLLocation(latitude: latitude, longitude: longitude)

    search.start { [weak self] response, error in
      guard self?.nearbyPlacesSearch === search else { return }
      self?.nearbyPlacesSearch = nil
      if let error {
        result(FlutterError(code: "nearby_search_failed", message: error.localizedDescription, details: nil))
        return
      }
      var seen = Set<String>()
      let places: [[String: Any]] = (response?.mapItems ?? []).compactMap { item in
        let rawName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = self?.compactPlaceName(rawName, placemark: item.placemark) ?? rawName
        guard !name.isEmpty, seen.insert(name).inserted else { return nil }
        let location = item.placemark.location
        let distance = location.map { Int(origin.distance(from: $0).rounded()) } ?? 0
        return [
          "name": name,
          "address": self?.formattedAddress(item.placemark) ?? "",
          "distanceMeters": distance,
        ]
      }
      .sorted {
        ($0["distanceMeters"] as? Int ?? 0) < ($1["distanceMeters"] as? Int ?? 0)
      }
      result(Array(places.prefix(30)))
    }
  }

  private func compactPlaceName(_ rawName: String, placemark: MKPlacemark) -> String {
    var value = rawName
    for prefix in [
      placemark.country,
      placemark.administrativeArea,
      placemark.locality,
      placemark.subLocality,
    ].compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }) where !prefix.isEmpty {
      if value.hasPrefix(prefix) {
        value = String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    return value.trimmingCharacters(in: CharacterSet(charactersIn: " ·,，"))
  }

  private func formattedAddress(_ placemark: MKPlacemark) -> String {
    var parts: [String] = []
    for value in [
      placemark.administrativeArea,
      placemark.locality,
      placemark.subLocality,
      placemark.thoroughfare,
      placemark.subThoroughfare,
    ].compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }) where !value.isEmpty {
      if parts.last != value { parts.append(value) }
    }
    return parts.joined()
  }
}
