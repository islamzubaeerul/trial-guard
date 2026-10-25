import Foundation
import TrialGuardCore
import TrialGuardFixtures

// Prints {fixtureName: ParseResult-without-evidence} as JSON, for scripts/parser-parity.sh.
// Usage: swift run tgparse [fixtures-dir]

let dir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : Fixtures.defaultDirectory

do {
    var out: [String: Any] = [:]
    let encoder = JSONEncoder()
    for fx in try Fixtures.load(from: dir) {
        let data = try encoder.encode(TrialParser.parse(fx.input))
        var obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        obj.removeValue(forKey: "evidence")
        out[fx.name] = obj
    }
    let json = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(json)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("tgparse: \(error)\n".utf8))
    exit(1)
}
