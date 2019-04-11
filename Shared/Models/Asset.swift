//
//  Asset.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import MobileCoreServices
import YapDatabase
import CommonCrypto

/**
 Representation of a file asset in the database.
*/
class Asset: NSObject, Item, YapDatabaseRelationshipNode, Encodable {

    // MARK: Item

    static let collection = "assets"

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("Asset", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "Asset")
    }

    func compare(_ rhs: Asset) -> ComparisonResult {
        return created.compare(rhs.created)
    }


    // MARK: Asset

    static let defaultMimeType = "application/octet-stream"

    /*
     A tag which is used as a generic flag.
    */
    static let flag = "NSFW"

    let id: String
    let created: Date
    let uti: String
    private var _filename: String?
    var title: String?
    var desc: String?
    var location: String?
    var tags: [String]?
    var notes: String?
    var publicUrl: URL?
    var isUploaded = false
    private(set) var collectionId: String

    var author: String? {
        if let space = collection.project.space {
            var author = [String]()

            if let name = space.authorName {
                author.append(name)
            }

            if let role = space.authorRole {
                author.append(role)
            }

            if let other = space.authorOther {
                author.append(other)
            }

            if author.count > 0 {
                return author.joined(separator: ", ")
            }
        }

        return nil
    }

    var license: String? {
        return collection.project.license
    }

    var collection: Collection {
        get {
            var collection: Collection?

            Db.bgRwConn?.read { transaction in
                collection = transaction.object(forKey: self.collectionId, inCollection: Collection.collection) as? Collection
            }

            return collection!
        }
        set {
            collectionId = newValue.id
        }
    }

    /**
     Shortcut for `.collection.project`.
    */
    var project: Project {
        return collection.project
    }

    /**
     Shortcut for `.project.space`.
     */
    var space: Space? {
        return project.space
    }

    /**
     The MIME equivalent to the stored `uti` or "application/octet-stream" if the UTI has no MIME type.

     See [Wikipedia](https://en.wikipedia.org/wiki/Uniform_Type_Identifier) about UTIs.
     */
    var mimeType: String {
        get {
            if let mimeType = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType)?
                .takeRetainedValue() {

                return mimeType as String
            }

            return Asset.defaultMimeType
        }
    }

    /**
     The stored filename, if any stored, or a made up filename, which uses the `id` and
     a typical extension for that `uti`.
    */
    var filename: String {
        get {
            if let filename = _filename {
                return filename
            }

            if let ext = Asset.getFileExt(uti: uti) {
                return "\(id).\(ext)"
            }

            return id
        }
        set {
            _filename = newValue
        }
    }

    var file: URL? {
        get {
            return FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Constants.appGroup)?
                .appendingPathComponent(Asset.collection)
                .appendingPathComponent(id)
        }
    }

    /**
     The size of the attached file in bytes, if file exists and attributes can
     be read.
    */
    var filesize: UInt64? {
        if let filepath = file?.path,
            let attr = try? FileManager.default.attributesOfItem(atPath: filepath) {

            return attr[.size] as? UInt64
        }

        return nil
    }

    /**
     A SHA256 hash of the file content, if file can be read.

     Uses a 1 MByte buffer to keep RAM usage low.
    */
    var digest: Data? {
        if let url = file,
            let fh = try? FileHandle(forReadingFrom: url) {

            defer {
                fh.closeFile()
            }

            var context = CC_SHA256_CTX()
            CC_SHA256_Init(&context)

            let data = fh.readData(ofLength: 1024 * 1024)

            if data.count > 0 {
                data.withUnsafeBytes {
                    if let pointer = $0.baseAddress {
                        _ = CC_SHA256_Update(&context, pointer, UInt32(data.count))
                    }
                }
            }

            var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
            digest.withUnsafeMutableBytes {
                if let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                    _ = CC_SHA256_Final(pointer, &context)
                }
            }

            return digest
        }

        return nil
    }

    var thumb: URL? {
        get {
            return FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Constants.appGroup)?
                .appendingPathComponent(Asset.collection)
                .appendingPathComponent("\(id).thumb")
        }
    }

    var flagged: Bool {
        get {
            return tags?.contains(Asset.flag) ?? false
        }
        set {
            if newValue {
                if tags == nil {
                    tags = [Asset.flag]
                }
                else if !tags!.contains(Asset.flag) {
                    tags?.append(Asset.flag)
                }
            }
            else if tags?.contains(Asset.flag) ?? false {
                tags?.removeAll { $0 == Asset.flag }

                if tags?.count ?? 0 < 1 {
                    tags = nil
                }
            }
        }
    }

    init(_ uti: String, _ collection: Collection, id: String = UUID().uuidString, created: Date = Date()) {
        self.id = id
        self.created = created
        self.uti = uti
        self.collectionId = collection.id
    }


    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        id = decoder.decodeObject(forKey: "id") as? String ?? UUID().uuidString
        created = decoder.decodeObject(forKey: "created") as? Date ?? Date()
        uti = decoder.decodeObject(forKey: "uti") as! String
        _filename = decoder.decodeObject(forKey: "filename") as? String
        title = decoder.decodeObject(forKey: "title") as? String
        desc = decoder.decodeObject(forKey: "desc") as? String
        location = decoder.decodeObject(forKey: "location") as? String
        notes = decoder.decodeObject(forKey: "notes") as? String
        tags = decoder.decodeObject(forKey: "tags") as? [String]
        publicUrl = decoder.decodeObject(forKey: "publicUrl") as? URL
        isUploaded = decoder.decodeBool(forKey: "isUploaded")
        collectionId = decoder.decodeObject(forKey: "collectionId") as! String
    }

    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(created, forKey: "created")
        coder.encode(uti, forKey: "uti")
        coder.encode(_filename, forKey: "filename")
        coder.encode(title, forKey: "title")
        coder.encode(desc, forKey: "desc")
        coder.encode(location, forKey: "location")
        coder.encode(notes, forKey: "notes")
        coder.encode(tags, forKey: "tags")
        coder.encode(publicUrl, forKey: "publicUrl")
        coder.encode(isUploaded, forKey: "isUploaded")
        coder.encode(collectionId, forKey: "collectionId")
    }


    // MARK: Encodable

    enum CodingKeys: String, CodingKey {
        case author
        case title
        case desc = "description"
        case created = "dateCreated"
        case license = "usage"
        case location
        case notes
        case tags
        case mimeType = "contentType"
        case filesize = "contentLength"
        case filename = "originalFileName"
        case digest = "hash"
    }

    /**
     This will create the metadata which should be exported using a
     `JSONEncoder`.
    */
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let author = author {
            try container.encode(author, forKey: .author)
        }

        if title != nil {
            try container.encode(title, forKey: .title)
        }

        if desc != nil {
            try container.encode(desc, forKey: .desc)
        }

        try container.encode(created, forKey: .created)

        if license != nil {
            try container.encode(license, forKey: .license)
        }

        if location != nil {
            try container.encode(location, forKey: .location)
        }

        if notes != nil {
            try container.encode(notes, forKey: .notes)
        }

        if tags != nil {
            try container.encode(tags, forKey: .tags)
        }

        try container.encode(mimeType, forKey: .mimeType)

        if let filesize = filesize {
            try container.encode(filesize, forKey: .filesize)
        }

        try container.encode(filename, forKey: .filename)

        if let filehash = digest {
            try container.encode(filehash, forKey: .digest)
        }
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), created=\(created), "
            + "uti=\(uti), title=\(title ?? "nil"), desc=\(desc ?? "nil"), "
            + "location=\(location ?? "nil"), notes=\(notes ?? "nil"), "
            + "tags=\(tags?.description ?? "nil"), "
            + "mimeType=\(mimeType), filename=\(filename), "
            + "file=\(file?.description ?? "nil"), thumb=\(thumb?.description ?? "nil"), "
            + "publicUrl=\(publicUrl?.absoluteString ?? "nil"), "
            + "isUploaded=\(isUploaded)]"
    }


    // MARK: YapDatabaseRelationshipNode

    /**
     YapDatabase will delete file and thumbnail, when object is deleted from db.
    */
    func yapDatabaseRelationshipEdges() -> [YapDatabaseRelationshipEdge]? {
        var edges = [YapDatabaseRelationshipEdge]()

        if let file = self.file,
            FileManager.default.fileExists(atPath: file.path) {
            edges.append(YapDatabaseRelationshipEdge(
                name: "file", destinationFileURL: file,
                nodeDeleteRules: .deleteDestinationIfSourceDeleted))
        }

        if let thumb = self.thumb,
            FileManager.default.fileExists(atPath: thumb.path) {
            edges.append(YapDatabaseRelationshipEdge(
                name: "thumb", destinationFileURL: thumb,
                nodeDeleteRules: .deleteDestinationIfSourceDeleted))
        }

        edges.append(YapDatabaseRelationshipEdge(
            name: "collection", destinationKey: collectionId, collection: Collection.collection,
            nodeDeleteRules: .deleteSourceIfDestinationDeleted))

        return edges
    }


    // MARK: Methods

    /**
     Returns a thumbnail image of the asset or a default image.

     In case of the asset beeing an image or video, the thumbnail should be a smaller version of
     the image, resp. a still shot of the video. In all other cases, a default image should be
     returned.

     - returns: A thumbnail `UIImage` of the asset or a default image.
    */
    func getThumbnail() -> UIImage? {
        if let thumb = thumb,
            let data = try? Data(contentsOf: thumb),
            let image = UIImage(data: data) {
            return image
        }

        return UIImage(named: "NoImage")
    }

    // MARK: Class methods

    /**
     See [Wikipedia](https://en.wikipedia.org/wiki/Uniform_Type_Identifier) about UTIs.

     - parameter uti: A Uniform Type Identifier
     - returns: The standard file extension or `nil` if no UTI or nothing found.
     */
    class func getFileExt(uti: String?) -> String? {
        if let uti = uti {
            if let ext = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassFilenameExtension)?
                .takeRetainedValue() {

                return ext as String
            }
        }

        return nil
    }
}
