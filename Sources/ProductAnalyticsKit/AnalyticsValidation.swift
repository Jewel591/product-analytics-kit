import Foundation

public enum AnalyticsValidationError: Error, Sendable, Equatable {
    case invalidEventName(String)
    case reservedEventName(String)
    case tooManyProperties(Int)
    case invalidPropertyKey(String)
    case sensitivePropertyKey(String)
    case invalidPropertyValue(String)
    case sensitivePropertyValue(String)
    case invalidUserID
}

enum AnalyticsValidation {
    static let maximumPropertyCount = 24
    static let maximumStringLength = 128

    private static let forbiddenExactKeys: Set<String> = [
        "account_id",
        "address",
        "authorization",
        "device_id",
        "display_name",
        "distinct_id",
        "email",
        "email_address",
        "full_name",
        "idfa",
        "idfv",
        "name",
        "password",
        "phone",
        "phone_number",
        "token",
        "user_id",
        "username",
    ]

    private static let forbiddenKeyFragments = [
        "authorization",
        "credential",
        "password",
        "secret",
        "token",
    ]

    static func validateEventName(_ name: String, allowsStudioPrefix: Bool) throws {
        guard isSnakeCaseIdentifier(name, maximumLength: 64) else {
            throw AnalyticsValidationError.invalidEventName(name)
        }
        guard allowsStudioPrefix || !name.hasPrefix("studio_") else {
            throw AnalyticsValidationError.reservedEventName(name)
        }
    }

    static func validateProperties(_ properties: [String: AnalyticsPropertyValue]) throws {
        guard properties.count <= maximumPropertyCount else {
            throw AnalyticsValidationError.tooManyProperties(properties.count)
        }
        for (key, value) in properties {
            guard isSnakeCaseIdentifier(key, maximumLength: 64) else {
                throw AnalyticsValidationError.invalidPropertyKey(key)
            }
            let normalized = key.lowercased()
            guard !forbiddenExactKeys.contains(normalized),
                  !forbiddenKeyFragments.contains(where: normalized.contains)
            else {
                throw AnalyticsValidationError.sensitivePropertyKey(key)
            }
            try validate(value, key: key)
        }
    }

    static func validateUserID(_ userID: String) throws {
        guard !userID.isEmpty,
              userID.count <= maximumStringLength,
              userID == userID.trimmingCharacters(in: .whitespacesAndNewlines),
              !userID.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !looksSensitive(userID)
        else {
            throw AnalyticsValidationError.invalidUserID
        }
    }

    static func validateProjectToken(_ token: String) -> Bool {
        guard token.hasPrefix("phc_"), token.count >= 12, token.count <= 256 else {
            return false
        }
        return token.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")).contains($0)
        }
    }

    private static func validate(_ value: AnalyticsPropertyValue, key: String) throws {
        switch value {
        case let .string(string):
            guard !string.isEmpty,
                  string.count <= maximumStringLength,
                  !string.unicodeScalars.contains(where: CharacterSet.newlines.contains)
            else {
                throw AnalyticsValidationError.invalidPropertyValue(key)
            }
            guard !looksSensitive(string) else {
                throw AnalyticsValidationError.sensitivePropertyValue(key)
            }
        case let .double(number):
            guard number.isFinite else {
                throw AnalyticsValidationError.invalidPropertyValue(key)
            }
        case .int, .bool:
            break
        }
    }

    private static func isSnakeCaseIdentifier(
        _ value: String,
        maximumLength: Int
    ) -> Bool {
        guard !value.isEmpty, value.count <= maximumLength else { return false }
        let scalars = Array(value.unicodeScalars)
        guard let first = scalars.first,
              CharacterSet.lowercaseLetters.contains(first),
              first.isASCII
        else {
            return false
        }
        var previousWasUnderscore = false
        for scalar in scalars {
            let isLowercaseASCII = scalar.isASCII
                && CharacterSet.lowercaseLetters.contains(scalar)
            let isDigit = scalar.isASCII && CharacterSet.decimalDigits.contains(scalar)
            let isUnderscore = scalar == "_"
            guard isLowercaseASCII || isDigit || isUnderscore else { return false }
            guard !(isUnderscore && previousWasUnderscore) else { return false }
            previousWasUnderscore = isUnderscore
        }
        return !previousWasUnderscore
    }

    private static func looksSensitive(_ value: String) -> Bool {
        let lowercase = value.lowercased()
        if lowercase.hasPrefix("http://") || lowercase.hasPrefix("https://")
            || lowercase.hasPrefix("bearer ") || lowercase.hasPrefix("phc_")
            || lowercase.hasPrefix("sk_") {
            return true
        }

        if value.range(
            of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }

        let jwtSegments = value.split(separator: ".", omittingEmptySubsequences: false)
        if jwtSegments.count == 3, value.hasPrefix("eyJ") {
            return true
        }
        return false
    }
}
