import Foundation

// MARK: - Address Note Model

struct AddressNote: Codable, Identifiable {
    let id: String
    var address: String
    var tags: [String]
    var details: String
    var createdAt: String
    var updatedAt: String
}

// MARK: - Preset Tags
// These match what the admin portal offers.
// Emoji + label shown as pills on the call screen.

struct NoteTag {
    let key: String
    let emoji: String
    let label: String
    let color: TagColor
}

enum TagColor {
    case red, orange, yellow, blue, purple, gray
}

let presetTags: [NoteTag] = [
    NoteTag(key: "overweight",   emoji: "⚖️",  label: "Overweight",      color: .orange),
    NoteTag(key: "stairchair",   emoji: "🪑",  label: "Stair Chair",     color: .blue),
    NoteTag(key: "pd_needed",    emoji: "👮",  label: "PD Needed",       color: .red),
    NoteTag(key: "dog",          emoji: "🐕",  label: "Dog on Premises", color: .orange),
    NoteTag(key: "violent",      emoji: "⚠️",  label: "Violent Patient", color: .red),
    NoteTag(key: "bariatric",    emoji: "🏥",  label: "Bariatric",       color: .orange),
    NoteTag(key: "oxygen",       emoji: "💨",  label: "Home Oxygen",     color: .blue),
    NoteTag(key: "key_box",      emoji: "🔑",  label: "Key Box",         color: .yellow),
    NoteTag(key: "elevator",     emoji: "🛗",  label: "Elevator",        color: .gray),
    NoteTag(key: "no_elevator",  emoji: "🚫",  label: "No Elevator",     color: .red),
    NoteTag(key: "gated",        emoji: "🚧",  label: "Gated Community", color: .yellow),
    NoteTag(key: "hoarder",      emoji: "📦",  label: "Hoarder",         color: .orange),
    NoteTag(key: "dnr",          emoji: "📋",  label: "DNR on File",     color: .purple),
    NoteTag(key: "frequent",     emoji: "🔄",  label: "Frequent Caller", color: .gray),
]

// MARK: - Manager

class AddressNotesManager {
    static let shared = AddressNotesManager()
    private init() {}

    private var allNotes: [AddressNote] = []

    // Called by EMSSocketManager when notesUpdate event arrives
    func handleNotesUpdate(_ data: Any) {
        guard let payload = data as? [[String: Any]] else { return }

        allNotes = payload.compactMap { dict -> AddressNote? in
            guard
                let id      = dict["id"]      as? String,
                let address = dict["address"] as? String
            else { return nil }

            return AddressNote(
                id:        id,
                address:   address,
                tags:      dict["tags"]    as? [String] ?? [],
                details:   dict["details"] as? String   ?? "",
                createdAt: dict["createdAt"] as? String ?? "",
                updatedAt: dict["updatedAt"] as? String ?? ""
            )
        }

        print("📍 Notes updated: \(allNotes.count) address note(s)")
    }

    // Called on app launch to pre-fetch notes
    func fetchNotes(serverURL: String) {
        guard let url = URL(string: "\(serverURL)/notes") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let notesArray = json["notes"] as? [[String: Any]]
            else { return }

            DispatchQueue.main.async {
                self?.handleNotesUpdate(notesArray)
                NotificationCenter.default.post(name: NSNotification.Name("EMSNotesUpdated"), object: nil)
            }
        }.resume()
    }

    // Fuzzy match notes to a call address
    func notes(for address: String) -> [AddressNote] {
        guard !address.isEmpty else { return [] }
        let query = address.lowercased()

        return allNotes.filter { note in
            let noteAddr = note.address.lowercased()
            if noteAddr.contains(query) || query.contains(noteAddr) { return true }

            // Word-level overlap — match on street number + name
            let queryWords = query.split(separator: " ").map(String.init).filter { $0.count > 2 }
            let noteWords  = noteAddr.split(separator: " ").map(String.init).filter { $0.count > 2 }
            let overlap    = queryWords.filter { qw in noteWords.contains { $0.contains(qw) || qw.contains($0) } }
            return overlap.count >= 2
        }
    }

    // Look up tag display info from key
    func tagInfo(for key: String) -> NoteTag? {
        presetTags.first { $0.key == key }
    }
}
