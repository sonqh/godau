import Foundation

/// A string key with its ordered `%@` arguments. Presentation logic returns these;
/// `Strings` turns them into text in one UI language.
public struct LocalizedText: Equatable, Hashable, Sendable {
    public let key: String
    public let args: [String]

    public init(_ key: String, _ args: String...) {
        self.key = key
        self.args = args
    }

    public init(key: String, args: [String]) {
        self.key = key
        self.args = args
    }

    /// An argument that is itself a string key, localized in the same language.
    public static func reference(_ key: String) -> String { referencePrefix + key }

    static let referencePrefix = "@key:"
}

public enum UILanguage: String, Equatable, Hashable, Sendable, CaseIterable {
    case vi, en

    /// Follows the macOS preferred language order; English when neither language is listed.
    public static func preferred(_ languages: [String] = Locale.preferredLanguages) -> UILanguage {
        for tag in languages {
            let code = tag.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            if let code, let language = UILanguage(rawValue: code) { return language }
        }
        return .en
    }
}

/// String tables read from `Localizable.xcstrings`. The catalog is copied, not compiled,
/// so the Command Line Tools build needs no Xcode string compiler.
public struct StringTable: Sendable {
    /// key -> language -> value
    public let entries: [String: [UILanguage: String]]

    public init(entries: [String: [UILanguage: String]]) {
        self.entries = entries
    }

    public init(catalog data: Data) throws {
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)
        var entries: [String: [UILanguage: String]] = [:]
        for (key, entry) in catalog.strings {
            var values: [UILanguage: String] = [:]
            for (code, localization) in entry.localizations ?? [:] {
                if let language = UILanguage(rawValue: code), let value = localization.stringUnit?.value {
                    values[language] = value
                }
            }
            entries[key] = values
        }
        self.entries = entries
    }

    /// The bundled table. The app bundle carries the catalog in `Contents/Resources`;
    /// SwiftPM test and debug runs use the package resource bundle.
    public static let bundled: StringTable = {
        let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings")
            ?? Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings")
        guard let url, let data = try? Data(contentsOf: url), let table = try? StringTable(catalog: data) else {
            return StringTable(entries: [:])
        }
        return table
    }()

    private struct Catalog: Decodable {
        let strings: [String: Entry]
    }
    private struct Entry: Decodable {
        let localizations: [String: Localization]?
    }
    private struct Localization: Decodable {
        let stringUnit: StringUnit?
    }
    private struct StringUnit: Decodable {
        let value: String
    }
}

/// Text in one UI language. Every surface uses one instance, so one surface shows one language.
public struct Strings: Sendable {
    public let language: UILanguage
    public let table: StringTable

    public init(language: UILanguage = .preferred(), table: StringTable = .bundled) {
        self.language = language
        self.table = table
    }

    /// Returns the key itself when a string is missing, so a gap is visible in review and caught by tests.
    public func text(_ key: String, _ args: [String] = []) -> String {
        guard let format = table.entries[key]?[language] else { return key }
        let resolved = args.map { arg in
            arg.hasPrefix(LocalizedText.referencePrefix)
                ? text(String(arg.dropFirst(LocalizedText.referencePrefix.count))) : arg
        }
        return Self.substitute(format, resolved)
    }

    public func callAsFunction(_ key: String, _ args: String...) -> String { text(key, args) }

    public func callAsFunction(_ value: LocalizedText) -> String { text(value.key, value.args) }

    /// Replaces each `%@` in order. Other `%` sequences stay as written.
    static func substitute(_ format: String, _ args: [String]) -> String {
        guard !args.isEmpty else { return format }
        var result = ""
        var remaining = args[...]
        var rest = format[...]
        while let range = rest.range(of: "%@") {
            result += rest[..<range.lowerBound]
            result += remaining.popFirst() ?? ""
            rest = rest[range.upperBound...]
        }
        return result + rest
    }
}
