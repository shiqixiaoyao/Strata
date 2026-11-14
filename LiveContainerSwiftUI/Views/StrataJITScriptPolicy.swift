import Foundation

enum StrataJITScriptMode: String, CaseIterable, Identifiable {
    case automatic, universal, custom
    var id: String { rawValue }
    var title: String {
        switch self { case .automatic: return "Automatic".loc; case .universal: return "Built-in Universal".loc; case .custom: return "Imported script".loc }
    }
}
enum StrataJITScriptPolicy {
    // Verified protocol declarations; never infer compatibility from an app's display name.
    static let universalIDs: Set<String> = ["dev.espressu.EspressU", "com.kdt.LiveExec32"]
    static func resolve(mode: StrataJITScriptMode, identifier: String, imported: String?, universal: String?) -> String? {
        switch mode {
        case .custom: return imported?.isEmpty == false ? imported : nil
        case .universal: return universal
        case .automatic:
            if let imported, !imported.isEmpty { return imported }
            return universalIDs.contains(identifier) ? universal : nil
        }
    }
}
