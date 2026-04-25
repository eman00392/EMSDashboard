//
//  WeatherManager.swift
//  EMSDashboard
//
//  Created by Ethan Bernstein on 4/23/26.
//

import Foundation
import Combine

// MARK: - Weather Data Models

struct EMSWeather {
    var temp: Int
    var unit: String            // "F" or "C"
    var wind: String            // e.g. "12 mph"
    var windDir: String         // e.g. "NW"
    var shortForecast: String   // e.g. "Partly Cloudy"

    var displayTemp: String { "\(temp)°\(unit)" }
    var displayWind: String { "\(wind) \(windDir)" }

    var weatherIcon: String {
        let f = shortForecast.lowercased()
        if f.contains("thunder")              { return "⛈" }
        if f.contains("snow")                 { return "🌨" }
        if f.contains("rain") || f.contains("shower") { return "🌧" }
        if f.contains("fog")                  { return "🌫" }
        if f.contains("cloudy")               { return "☁️" }
        if f.contains("partly")               { return "⛅️" }
        if f.contains("clear") || f.contains("sunny") { return "☀️" }
        if f.contains("wind")                 { return "💨" }
        return "🌡"
    }
}

struct EMSWeatherAlert {
    var headline: String
    var severity: String
    var description: String

    var isActive: Bool {
        return severity != "None"
    }

    var severityColor: String {
        switch severity.lowercased() {
        case "extreme":  return "red"
        case "severe":   return "orange"
        case "moderate": return "yellow"
        default:         return "gray"
        }
    }
}

// MARK: - Weather Manager
// Listens to the weatherUpdate and weatherAlertsUpdate Socket.IO events
// that your existing server.js already emits every 5 minutes.

class WeatherManager: ObservableObject {
    static let shared = WeatherManager()
    private init() {}

    @Published var currentWeather: EMSWeather? = nil
    @Published var currentAlerts: [EMSWeatherAlert] = []

    // MARK: - Parse weatherUpdate event
    // Matches server.js: io.emit("weatherUpdate", currentWeather)
    // where currentWeather = { temp, unit, wind, windDir, shortForecast }

    func handleWeatherUpdate(_ data: Any) {
        guard let dict = data as? [String: Any] else { return }

        let weather = EMSWeather(
            temp:          dict["temp"]          as? Int    ?? 0,
            unit:          dict["unit"]          as? String ?? "F",
            wind:          dict["wind"]          as? String ?? "",
            windDir:       dict["windDir"]       as? String ?? "",
            shortForecast: dict["shortForecast"] as? String ?? ""
        )

        DispatchQueue.main.async {
            self.currentWeather = weather
            print("🌤 Weather updated: \(weather.displayTemp) \(weather.shortForecast)")
        }
    }

    // MARK: - Parse weatherAlertsUpdate event
    // Matches server.js: io.emit("weatherAlertsUpdate", currentAlerts)
    // where each alert = { headline, severity, description }

    func handleAlertsUpdate(_ data: Any) {
        guard let alerts = data as? [[String: Any]] else { return }

        let parsed = alerts.map { dict in
            EMSWeatherAlert(
                headline:    dict["headline"]    as? String ?? "",
                severity:    dict["severity"]    as? String ?? "None",
                description: dict["description"] as? String ?? ""
            )
        }

        DispatchQueue.main.async {
            self.currentAlerts = parsed
            print("🌩 Weather alerts updated: \(parsed.count) alert(s)")
        }
    }
}
