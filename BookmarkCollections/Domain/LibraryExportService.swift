import Foundation
import SwiftData

@MainActor
struct LibraryExportService {
    let context: ModelContext

    func exportJSON(exportedAt: Date = Date()) throws -> Data {
        let collections = try context.fetch(
            FetchDescriptor<BookmarkCollection>(sortBy: [
                SortDescriptor(\BookmarkCollection.sortPosition),
                SortDescriptor(\BookmarkCollection.id)
            ])
        )
        let allBookmarks = try context.fetch(
            FetchDescriptor<Bookmark>(sortBy: [
                SortDescriptor(\Bookmark.createdAt),
                SortDescriptor(\Bookmark.id)
            ])
        )
        let bookmarks = allBookmarks.filter { $0.kind == .link }
        let snippets = allBookmarks.filter { $0.kind == .text }
        let document = BackupDocument(
            exportedAt: exportedAt,
            collections: collections.map { collection in
                BackupDocument.CollectionRecord(
                    id: collection.id,
                    name: collection.name,
                    sortPosition: collection.sortPosition,
                    createdAt: collection.createdAt,
                    modifiedAt: collection.modifiedAt
                )
            },
            bookmarks: bookmarks.map { bookmark in
                BackupDocument.BookmarkRecord(
                    id: bookmark.id,
                    urlString: bookmark.urlString,
                    normalizedURLString: bookmark.normalizedURLString,
                    title: bookmark.title,
                    domain: bookmark.domain,
                    isFavorite: bookmark.isFavorite,
                    collectionID: bookmark.collection?.id,
                    createdAt: bookmark.createdAt,
                    modifiedAt: bookmark.modifiedAt,
                    deletedAt: bookmark.deletedAt,
                    lastOpenedAt: bookmark.lastOpenedAt
                )
            },
            snippets: snippets.map { snippet in
                BackupDocument.SnippetRecord(
                    id: snippet.id,
                    title: snippet.title,
                    body: snippet.snippetBody,
                    sourceUrl: snippet.urlString.isEmpty ? nil : snippet.urlString,
                    isFavorite: snippet.isFavorite,
                    collectionID: snippet.collection?.id,
                    createdAt: snippet.createdAt,
                    modifiedAt: snippet.modifiedAt,
                    deletedAt: snippet.deletedAt,
                    lastOpenedAt: snippet.lastOpenedAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    func exportHTML() throws -> Data {
        let collections = try context.fetch(
            FetchDescriptor<BookmarkCollection>(sortBy: [
                SortDescriptor(\BookmarkCollection.sortPosition),
                SortDescriptor(\BookmarkCollection.id)
            ])
        )
        let activeBookmarks = try context.fetch(
            FetchDescriptor<Bookmark>(sortBy: [
                SortDescriptor(\Bookmark.createdAt),
                SortDescriptor(\Bookmark.id)
            ])
        ).filter { $0.deletedAt == nil && $0.kind == .link }

        var lines = [
            "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
            "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">",
            "<TITLE>Bookmark Collections</TITLE>",
            "<H1>Bookmark Collections</H1>",
            "<DL><p>"
        ]

        for collection in collections {
            let bookmarks = activeBookmarks.filter { $0.collection?.id == collection.id }
            appendFolder(named: collection.name, bookmarks: bookmarks, to: &lines)
        }
        let unfiled = activeBookmarks.filter { $0.collection == nil }
        if !unfiled.isEmpty {
            appendFolder(named: "Unfiled", bookmarks: unfiled, to: &lines)
        }
        lines.append("</DL><p>")

        return Data(lines.joined(separator: "\n").utf8)
    }

    private func appendFolder(
        named name: String,
        bookmarks: [Bookmark],
        to lines: inout [String]
    ) {
        lines.append("    <DT><H3>\(escape(name))</H3>")
        lines.append("    <DL><p>")
        for bookmark in bookmarks {
            let title = bookmark.title.isEmpty
                ? (bookmark.domain.isEmpty ? bookmark.urlString : bookmark.domain)
                : bookmark.title
            let added = Int(bookmark.createdAt.timeIntervalSince1970)
            let favorite = bookmark.isFavorite ? " TAGS=\"favorite\"" : ""
            lines.append(
                "        <DT><A HREF=\"\(escape(bookmark.urlString))\" ADD_DATE=\"\(added)\"\(favorite)>\(escape(title))</A>"
            )
        }
        lines.append("    </DL><p>")
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

