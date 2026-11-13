//
//  SandboxBookmarks.swift
//  MacMulator
//
//  Keeps the files and folders the user picked accessible across launches in the
//  App Store flavor.
//
//  A sandboxed application only gets access to a user-selected path for the
//  lifetime of the process that showed the open panel. A security-scoped
//  bookmark turns that into a grant that can be re-activated at the next launch.
//  The Qemu processes the application spawns inherit its sandbox, and with it
//  the access to these paths. The Enthusiast flavor is not sandboxed and needs
//  none of this: there the methods do nothing.
//

import Foundation

class SandboxBookmarks {
    /// UserDefaults key of the dictionary path -> security-scoped bookmark data.
    private static let preferenceKey = "securityScopedBookmarks"

    /// Resolved URLs whose security-scoped access is currently active, by path.
    private static var activeURLs: [String: URL] = [:]

    /// Records a path the user granted access to, through an open panel or by opening a
    /// file with the application, so that it stays accessible at the next launch.
    static func remember(_ url: URL) {
        #if APPSTORE
            let path = url.standardizedFileURL.path
            // Everything inside the container is always accessible.
            if path.hasPrefix(NSHomeDirectory()) || activeURLs[path] != nil {
                return
            }
            do {
                let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                var bookmarks = storedBookmarks()
                bookmarks[path] = data
                UserDefaults.standard.set(bookmarks, forKey: preferenceKey)
                // The open panel already granted access for this process; keep the URL so that
                // later calls know the path is covered.
                activeURLs[path] = url
            } catch {
                print("Cannot create a security-scoped bookmark for " + path + ": " + error.localizedDescription)
            }
        #endif
    }

    /// Re-activates the access to every remembered path. Call once, at launch, before any
    /// user path is read. Bookmarks that no longer resolve are forgotten; stale ones are renewed.
    static func restoreAll() {
        #if APPSTORE
            var bookmarks = storedBookmarks()
            var changed = false
            for (path, data) in bookmarks {
                var stale = false
                guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else {
                    print("Forgetting the security-scoped bookmark of " + path + ": it no longer resolves")
                    bookmarks.removeValue(forKey: path)
                    changed = true
                    continue
                }
                if !url.startAccessingSecurityScopedResource() {
                    print("Cannot access " + path + " through its security-scoped bookmark")
                    continue
                }
                activeURLs[path] = url
                if stale, let renewed = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    bookmarks[path] = renewed
                    changed = true
                }
            }
            if changed {
                UserDefaults.standard.set(bookmarks, forKey: preferenceKey)
            }
        #endif
    }

    /// Whether `path` is covered by an active grant (itself, or a folder containing it).
    /// Paths inside the container are always accessible.
    static func hasAccess(to path: String) -> Bool {
        #if APPSTORE
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            if standardized.hasPrefix(NSHomeDirectory()) {
                return true
            }
            return activeURLs.keys.contains { granted in
                standardized == granted || standardized.hasPrefix(granted + "/")
            }
        #else
            return true
        #endif
    }

    #if APPSTORE
        private static func storedBookmarks() -> [String: Data] {
            UserDefaults.standard.dictionary(forKey: preferenceKey) as? [String: Data] ?? [:]
        }
    #endif
}
