import Foundation
import Combine
import CoreLocation

// MARK: - EMS Call Model

struct EMSCall {
    var address:   String
    var cross:     String
    var problem:   String
    var comments:  String   // raw Active911 details field
    var units:     String
    var type:      String
    var age:       String
    var sex:       String
    var conscious: String
    var breathing: String
    var lat:       Double
    var lng:       Double

    // MARK: - Problem Display
    // Mirrors the 4-priority logic from index.html lines 1188-1218

    var displayProblem: String {
        let typeUpper = type.uppercased()

        // Priority 1: explicit "Problem: XYZ" in comments
        if let match = comments.range(of: #"Problem:\s*([^,\n]+)"#, options: .regularExpression) {
            let raw = String(comments[match])
            if let colonRange = raw.range(of: ":") {
                let extracted = String(raw[raw.index(after: colonRange.upperBound)...])
                    .trimmingCharacters(in: .whitespaces)
                if !extracted.isEmpty { return extracted.uppercased() }
            }
        }

        // Priority 2: ALARM type → Medical Alarm
        if typeUpper.contains("ALARM") || typeUpper.contains("MED") {
            if typeUpper.contains("ALARM") { return "MEDICAL ALARM" }
        }

        // Priority 3: parsed from comments — only if looks like real medical text
        let parsed = CallCommentParser.parse(problem: problem, comments: comments)
        let p = parsed.problem
        let looksLikeNoise = p.range(of: #"\d{3}[-.\s]\d{4}"#, options: .regularExpression) != nil ||
                             p.range(of: #"^[A-Z]+\s+\d{3}"#, options: .regularExpression) != nil ||
                             (p.split(separator: " ").count <= 1 && p.count > 12)
        if !p.isEmpty && !looksLikeNoise { return p }

        // Priority 4: fallback to raw problem field
        return problem.uppercased()
    }

    // MARK: - Patient Info (from parser)

    var parsedAge: String {
        let p = CallCommentParser.parse(problem: problem, comments: comments)
        return p.age.isEmpty ? age : p.age
    }

    var parsedSex: String {
        let p = CallCommentParser.parse(problem: problem, comments: comments)
        return p.sex.isEmpty ? sex : p.sex
    }

    var patientSummary: String {
        let a = parsedAge
        let s = parsedSex
        var parts: [String] = []
        if !a.isEmpty || !s.isEmpty { parts.append("\(a)\(s)") }
        if !conscious.isEmpty       { parts.append(conscious) }
        if !breathing.isEmpty       { parts.append(breathing) }
        return parts.isEmpty ? "No patient info" : parts.joined(separator: " · ")
    }

    // MARK: - Unit / Agency Detection
    // Mirrors web dashboard lines 1256-1267

    var callOrigin: CallOrigin { UnitConfig.origin(from: units, type: type) }

    var isMutualAid: Bool {
        let u = units.uppercased()
        let t = type.uppercased()
        return u.contains("MUTUAL") || u.contains("M/A") || t == "MA"
    }

    var originLabel: String {
        switch callOrigin {
        case .eastchester: return "EASTCHESTER"
        case .pelham:      return isMutualAid ? "MUTUAL AID — PELHAM"    : "PELHAM CALL"
        case .scarsdale:   return isMutualAid ? "MUTUAL AID — SCARSDALE" : "SCARSDALE CALL"
        case .mutualAid:   return "MUTUAL AID"
        case .unknown:     return "EASTCHESTER"
        }
    }

    var unitLines: [String] {
        units
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map  { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var hasLocation: Bool { lat != 0 && lng != 0 }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - Comment Parser
// Mirrors parseComment() in index.html lines 1024-1095

struct ParsedComment {
    var problem: String
    var age:     String
    var sex:     String
}

class CallCommentParser {

    static func parse(problem: String, comments: String) -> ParsedComment {
        let raw = comments.isEmpty ? problem : comments

        // Strip noise patterns
        var cleaned = raw
        let strips = [
            #"http\S+"#,
            #"GPS[:\s]*[-\d.,\s]+"#,
            #"Event\s*Number[:\s]*\S+"#,
            #"E\d{7,}"#,
            #"TIME[:\s]*\d{2}:\d{2}:\d{2}"#,
            #"WPH2\S*"#,
            #"KNOX\s*BOX\s*ON\s*PREMISE"#,
            #"KNOX\S*"#,
            #"VOIP\s*#?\w*"#,
        ]
        strips.forEach { pattern in
            cleaned = cleaned.replacingOccurrences(
                of: pattern, with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        cleaned = cleaned
            .replacingOccurrences(of: #",\s*,"#, with: ",", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ", \t\n"))

        // Extract age + sex — matches: 86 Y/O/F, 85 YOF, 85 YOM, 85 YO F, etc.
        var age = ""
        var sex = ""

        let agePattern = #"\b(\d{1,3})\s*(?:Y\/O\/([MF])|YO([MF])|Y\/O\s*([MF])|YO\s*([MF]))"#
        if let match = cleaned.range(of: agePattern, options: [.regularExpression, .caseInsensitive]) {
            let token = String(cleaned[match])
            // Extract the digit
            if let numMatch = token.range(of: #"\d+"#, options: .regularExpression) {
                age = String(token[numMatch])
            }
            let upper = token.uppercased()
            if upper.contains("F") { sex = "F" } else if upper.contains("M") { sex = "M" }
            cleaned = cleaned.replacingCharacters(in: match, with: "").trimmingCharacters(in: .whitespaces)
        }

        // Skip-segment patterns (same as web dashboard)
        let skipPatterns: [String] = [
            #"^#"#,
            #"^NURSE\b"#,
            #"^CALLBACK\b"#,
            #"^RELAY\b"#,
            #"^MEDCOM\b"#,
            #"\d{3}[-.\s]\d{3}[-.\s]\d{4}"#,
            #"\d{3}[-.\s]\d{4}"#,
            #"^[A-Z]+\s+\d{3}"#,
        ]

        let segments = cleaned
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let problemSegment = segments.first { seg in
            !skipPatterns.contains { pattern in
                seg.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            }
        } ?? ""

        return ParsedComment(
            problem: problemSegment.uppercased(),
            age:     age,
            sex:     sex
        )
    }
}

// MARK: - Call Data Model

class CallDataModel: ObservableObject {
    static let shared = CallDataModel()
    private init() {}

    @Published var currentCall: EMSCall? = nil
    @Published var isConnected: Bool     = false

    var lastNotifiedCallID: String {
        get { UserDefaults.standard.string(forKey: "lastNotifiedCallID") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastNotifiedCallID")
            UserDefaults.standard.synchronize()
        }
    }

    var activeCallDispatchTime: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: "activeCallDispatchTime")
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let d = newValue {
                UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "activeCallDispatchTime")
            } else {
                UserDefaults.standard.removeObject(forKey: "activeCallDispatchTime")
            }
            UserDefaults.standard.synchronize()
        }
    }
}
