import Foundation

struct GitMetadata: Equatable {
    let branch: String
    let isDirty: Bool
    let remoteOriginURL: String?

    var statusText: String {
        isDirty ? "Dirty" : "Clean"
    }
}
