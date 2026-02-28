import Foundation
import Security

// ---------------------------------------------------------------------------
// CodeIntegrityService — Validates app code signature at launch (C4)
// ---------------------------------------------------------------------------

/// Verifies the running app's code signature using SecCode APIs.
/// If integrity check fails, entitlement should degrade to free tier.
enum CodeIntegrityService {

    enum IntegrityResult: Sendable {
        case valid
        case invalid(String)
        case skipped // DEBUG builds
    }

    @MainActor
    static func validateAtLaunch() -> IntegrityResult {
        #if DEBUG
        return .skipped
        #else
        return performCodeSignatureCheck()
        #endif
    }

    private static func performCodeSignatureCheck() -> IntegrityResult {
        var code: SecCode?
        let copyStatus = SecCodeCopySelf(SecCSFlags(), &code)

        guard copyStatus == errSecSuccess, let secCode = code else {
            return .invalid("Failed to copy self code reference (status: \(copyStatus))")
        }

        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        guard !bundleIdentifier.isEmpty else {
            return .invalid("Missing bundle identifier for integrity check")
        }

        let configuredTeamID = (Bundle.main.object(forInfoDictionaryKey: "STRATA_EXPECTED_TEAM_ID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let expectedTeamID = configuredTeamID.isEmpty ? "4QZFT5Q76A" : configuredTeamID

        let requirementString = "anchor apple generic and identifier \"\(bundleIdentifier)\" and certificate leaf[subject.OU] = \"\(expectedTeamID)\""

        var requirement: SecRequirement?
        let createReqStatus = SecRequirementCreateWithString(requirementString as CFString, SecCSFlags(), &requirement)
        guard createReqStatus == errSecSuccess, let requirement else {
            return .invalid("Failed to create code requirement (status: \(createReqStatus))")
        }

        let checkStatus = SecCodeCheckValidity(secCode, SecCSFlags(), requirement)
        guard checkStatus == errSecSuccess else {
            return .invalid("Code signature validation failed (status: \(checkStatus))")
        }

        return .valid
    }
}
