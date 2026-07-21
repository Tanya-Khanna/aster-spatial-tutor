import Darwin
import Foundation

struct AppRelocationStatus: Equatable {
    let bundleURL: URL
    let isInApplications: Bool
    let isTranslocated: Bool
    let isQuarantined: Bool

    var requiresRelocation: Bool {
        !isInApplications || isTranslocated || isQuarantined
    }
}

enum AppRelocationError: LocalizedError {
    case invalidApplicationBundle
    case applicationsFolderUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidApplicationBundle:
            return "Aster✱ could not find the application bundle it is currently running from."
        case .applicationsFolderUnavailable:
            return "Aster✱ could not access your Applications folder. Drag the app there manually, then reopen it."
        }
    }
}

enum AppRelocationService {
    private static let quarantineAttribute = "com.apple.quarantine"

    static func status(
        for bundleURL: URL = Bundle.main.bundleURL,
        quarantineOverride: Bool? = nil
    ) -> AppRelocationStatus {
        let standardizedURL = bundleURL.standardizedFileURL
        let path = standardizedURL.path
        let applicationsPath = URL(fileURLWithPath: "/Applications", isDirectory: true).standardizedFileURL.path
        let userApplicationsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL.path
        let isInApplications = path.hasPrefix(applicationsPath + "/") || path.hasPrefix(userApplicationsPath + "/")

        // App Translocation mounts quarantined apps beneath a randomized AppTranslocation path.
        // We also inspect quarantine metadata because the original Downloads path can be observed
        // before (or after) macOS chooses to translocate it.
        let isTranslocated = path.contains("/AppTranslocation/")
        let isQuarantined = quarantineOverride ?? hasQuarantineAttribute(at: standardizedURL)

        return AppRelocationStatus(
            bundleURL: standardizedURL,
            isInApplications: isInApplications,
            isTranslocated: isTranslocated,
            isQuarantined: isQuarantined
        )
    }

    static func installInApplications(
        from sourceURL: URL,
        applicationsDirectory: URL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    ) throws -> URL {
        let fileManager = FileManager.default
        guard sourceURL.pathExtension == "app", fileManager.fileExists(atPath: sourceURL.path) else {
            throw AppRelocationError.invalidApplicationBundle
        }
        guard fileManager.fileExists(atPath: applicationsDirectory.path) else {
            throw AppRelocationError.applicationsFolderUnavailable
        }

        let destinationURL = applicationsDirectory.appendingPathComponent("Aster.app", isDirectory: true)
        if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            removeQuarantineRecursively(at: destinationURL)
            return destinationURL
        }

        let stagingURL = applicationsDirectory.appendingPathComponent(".Aster-installing-\(UUID().uuidString).app", isDirectory: true)
        let backupURL = applicationsDirectory.appendingPathComponent(".Aster-previous-\(UUID().uuidString).app", isDirectory: true)
        var backedUpExistingCopy = false

        do {
            try fileManager.copyItem(at: sourceURL, to: stagingURL)
            removeQuarantineRecursively(at: stagingURL)

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.moveItem(at: destinationURL, to: backupURL)
                backedUpExistingCopy = true
            }
            try fileManager.moveItem(at: stagingURL, to: destinationURL)

            if backedUpExistingCopy {
                try? fileManager.trashItem(at: backupURL, resultingItemURL: nil)
            }
            return destinationURL
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if backedUpExistingCopy,
               !fileManager.fileExists(atPath: destinationURL.path),
               fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.moveItem(at: backupURL, to: destinationURL)
            }
            throw error
        }
    }

    private static func hasQuarantineAttribute(at url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return getxattr(path, quarantineAttribute, nil, 0, 0, XATTR_NOFOLLOW) >= 0
        }
    }

    private static func removeQuarantineRecursively(at rootURL: URL) {
        removeQuarantineAttribute(at: rootURL)
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else { return }

        for case let childURL as URL in enumerator {
            removeQuarantineAttribute(at: childURL)
        }
    }

    private static func removeQuarantineAttribute(at url: URL) {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return }
            _ = removexattr(path, quarantineAttribute, XATTR_NOFOLLOW)
        }
    }
}
