//
//  Db.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 01.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 Encapsulates YapDatabase setup and connection creation.
 */
class Db {

    private static let DB_NAME = "open-archive.sqlite"

    private static var shared: YapDatabase? = {
        if let path = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroup)?
            .appendingPathComponent(DB_NAME) 
        {
//            print("[\(String(describing: Db.self))] path=\(path)")

            let options = YapDatabaseOptions()
            options.enableMultiProcessSupport = true

            return YapDatabase(url: path, options: options)
        }

        return nil
    }()

    public class func setup() {
//        DDLog.add(DDTTYLogger.sharedInstance)

        Space.fixArchiverName() // Needed for screenshot testing.
        WebDavSpace.fixArchiverName()
        DropboxSpace.fixArchiverName()
        IaSpace.fixArchiverName()
        GdriveSpace.fixArchiverName()
        shared?.setObjectPolicy(.copy, forCollection: Space.collection)

        Project.fixArchiverName()
        shared?.setObjectPolicy(.copy, forCollection: Project.collection)

        Collection.fixArchiverName()
        shared?.setObjectPolicy(.copy, forCollection: Collection.collection)

        Asset.fixArchiverName()
        shared?.setObjectPolicy(.copy, forCollection: Asset.collection)

        Upload.fixArchiverName()
        shared?.setObjectPolicy(.copy, forCollection: Upload.collection)

        shared?.register(AssetsByCollectionView(), withName: AssetsByCollectionView.name)
        shared?.register(AbcFilteredByProjectView(), withName: AbcFilteredByProjectView.name)
        shared?.register(AbcFilteredByCollectionView(), withName: AbcFilteredByCollectionView.name)
        shared?.register(UploadsView(), withName: UploadsView.name)
        shared?.register(ProjectsView(), withName: ProjectsView.name)
        shared?.register(ActiveProjectsView(), withName: ActiveProjectsView.name)
        shared?.register(CollectionsView(), withName: CollectionsView.name)
        shared?.register(SpacesView(), withName: SpacesView.name)

        // Enable relationships. (Also row -> file relationship handling!)
        shared?.register(YapDatabaseRelationship(), withName: "relationships")

        // Enable cross-process notifications.
        shared?.register(YapDatabaseCrossProcessNotification(identifier: DB_NAME), withName: "xProcNotification")
    }

    /**
     Hook the given method to `YapDatabaseModified` and `YapDatabaseModifiedExternally`
     notifications.

     - parameter observer: The class which will observe the notifications.
     - parameter selector: The method which will receive the notifications.
     - returns: The `NotificationCenter.default`
    */
    @discardableResult
    public class func add(observer: Any, _ selector: Selector) -> NotificationCenter {
        let nc = NotificationCenter.default

        nc.addObserver(observer, selector: selector, name: .YapDatabaseModified, object: nil)

        nc.addObserver(observer, selector: selector, name: .YapDatabaseModifiedExternally, object: nil)

        return nc
    }

    /**
     Create a new connection and begin an long-lived read transaction.

     This is what you want for UI threads to back `UITableView`s and the like.
    */
    public class func newLongLivedReadConn() -> YapDatabaseConnection? {
        let conn = newConnection()

        conn?.beginLongLivedReadTransaction()

        return conn
    }

    /**
     For background thread read/write transactions, use this connection, instead
     of one-off instances.

     That will reduce the cost of connection creation/destruction and will
     leverage the connection cache.
    */
    public static var bgRwConn: YapDatabaseConnection? = {
        return newConnection()
    }()

    /**
     SQLite only supports one write transaction at a time, so there's no use in
     using multiple connections for that.

     Reuse this connection for write-only stuff, it is specially prepared for
     that task.
    */
    public static var writeConn: YapDatabaseConnection? = {
        let conn = newConnection()

        // No object cache on write-only connections.
        conn?.objectCacheEnabled = false

        return conn
    }()

    // MARK: Private Methods

    private class func newConnection() -> YapDatabaseConnection? {
        let conn = shared?.newConnection()

        // 250 is default, currently just here for reference. Increase, if need be.
        conn?.objectCacheLimit = 250

        // We're currently not using metadata at all.
        conn?.metadataCacheEnabled = false

        return conn
    }
}

/**
 The app crashed once, because YapDatabase tried to call NSCopying protocol.
 Not sure, why but better implement it...
 */
protocol Item: NSSecureCoding, NSCopying {

    static var collection: String { get }

    /**
     Fix class de-/serialization errors due to iOS prefixing classes with the
     app/extension depending on which part of the app wrote it.

     Should look something like this:

     ```Swift
     NSKeyedArchiver.setClassName("MyItem", for: self)
     NSKeyedUnarchiver.setClass(self, forClassName: "MyItem")
     ```
     */
    static func fixArchiverName()

    /**
     The key to file this object under.
    */
    var id: String { get }

    associatedtype Item2: Item

    func compare(_ rhs: Item2) -> ComparisonResult

    /**
     Loads all cached object references.
     */
    func preheat(_ tx: YapDatabaseReadTransaction, deep: Bool)
}
