//
//  YapDatabase+Utils.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.04.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation
import YapDatabase

extension YapDatabaseConnection {

    func hasChanges(_ mappings: YapDatabaseViewMappings) -> Bool {
        let notifications = beginLongLivedReadTransaction()

        guard mappings.isNextSnapshot(notifications) else {
            update(mappings: mappings)

            return true
        }

        guard let viewConn = ext(mappings.view) as? YapDatabaseViewConnection else {
            return false
        }

        if viewConn.hasChanges(for: notifications) {
            update(mappings: mappings)

            return true
        }

        return false
    }

    func getChanges(_ mappings: YapDatabaseViewMappings) -> (forceFull: Bool,
                                                             sectionChanges: [YapDatabaseViewSectionChange],
                                                             rowChanges: [YapDatabaseViewRowChange])
    {
        let notifications = beginLongLivedReadTransaction()

        guard mappings.isNextSnapshot(notifications) else {
            update(mappings: mappings)

            return (true, [], [])
        }

        guard let viewConn = ext(mappings.view) as? YapDatabaseViewConnection else {
            return (false, [], [])
        }

        let changes = viewConn.getChanges(forNotifications: notifications, withMappings: mappings)

        return (false, changes.sectionChanges, changes.rowChanges)
    }

    func update(mappings: YapDatabaseViewMappings) {
        read { tx in
            mappings.update(with: tx)
        }
    }

    func objects<T: Item>(for keys: [String],
                          _ process: ((_ tx: YapDatabaseReadTransaction, _ object: inout T) -> Void)? = nil) -> [T]
    {
        var objects = [T]()

        read { tx in
            tx.enumerateObjects(forKeys: keys, inCollection: T.collection) { index, object, stop in
                if var object = object as? T {
                    process?(tx, &object)

                    objects.append(object)
                }
            }
        }

        return objects
    }

    func objects<T>(in section: Int, with mappings: YapDatabaseViewMappings?,
                    _ process: ((_ tx: YapDatabaseReadTransaction, _ object: inout T) -> Void)? = nil) -> [T]
    {
        var objects = [T]()

        guard let mappings = mappings,
              let group = mappings.group(forSection: UInt(section))
        else {
            return objects
        }

        iterate(group: group, in: mappings.view) { (tx, collection, key, object: T, index, stop) in
            var object = object
            process?(tx, &object)

            objects.append(object)
        }

        return objects
    }

    func objects<T>(at indexPaths: [IndexPath]?, in mappings: YapDatabaseViewMappings?,
                    _ process: ((_ tx: YapDatabaseReadTransaction, _ object: inout T) -> Void)? = nil) -> [T]
    {
        var objects = [T]()

        guard let indexPaths = indexPaths,
              let mappings = mappings
        else {
            return objects
        }

        read { tx in
            guard let viewTx = tx.forView(mappings.view) else {
                return
            }

            for indexPath in indexPaths {
                if var object = viewTx.object(at: indexPath, with: mappings) as? T {
                    process?(tx, &object)

                    objects.append(object)
                }
            }
        }

        return objects
    }

    func object<T>(at indexPath: IndexPath, in mappings: YapDatabaseViewMappings?,
                   _ process: ((_ tx: YapDatabaseReadTransaction, _ object: inout T) -> Void)? = nil) -> T?
    {
        objects(at: [indexPath], in: mappings, process).first
    }

    func object<T>(for key: String?, in collection: String?,
                   _ process: ((_ tx: YapDatabaseReadTransaction, _ object: inout T) -> Void)? = nil) -> T?
    {
        guard let key = key else {
            return nil
        }

        var object: T? = nil

        read { tx in
            if var o: T = tx.object(for: key, in: collection) {
                process?(tx, &o)

                object = o
            }
        }

        return object
    }

    func object<T: Item>(for key: String?,
                         _ process: ((_ tx: YapDatabaseReadTransaction, _ object: inout T) -> Void)? = nil) -> T?
    {
        guard let key = key else {
            return nil
        }

        var object: T? = nil

        read { tx in
            if var o: T = tx.object(for: key) {
                process?(tx, &o)

                object = o
            }
        }

        return object
    }

    func indexPath(for key: String?, in collection: String?, with mappings: YapDatabaseViewMappings?) -> IndexPath? {
        guard let key = key,
              let mappings = mappings
        else {
            return nil
        }

        var indexPath: IndexPath? = nil

        read { tx in
            indexPath = tx.forView(mappings.view)?
                .indexPath(forKey: key, inCollection: collection, with: mappings)
        }

        return indexPath
    }

    func indexPath<T: Item>(of object: T?, with mappings: YapDatabaseViewMappings?) -> IndexPath? {
        indexPath(for: object?.id, in: T.collection, with: mappings)
    }

    func setObject(_ object: Any?, for key: String, in collection: String?) {
        asyncReadWrite { tx in
            tx.setObject(object, forKey: key, inCollection: collection)
        }
    }

    func setObject<T: Item>(_ object: T) {
        asyncReadWrite { tx in
            tx.setObject(object)
        }
    }

    func find<T: Item>(where: (T) -> Bool) -> T? {
        var found: T? = nil

        read { tx in
            found = tx.find(where: `where`)
        }

        return found
    }

    func iterate<T>(group: String?, in view: String?,
                    using block: (_ tx: YapDatabaseReadTransaction, _ collection: String, _ key: String, _ object: T, _ index: Int, _ stop: inout Bool) -> Void)
    {
        guard let group = group,
              let view = view
        else {
            return
        }

        read { tx in
            tx.iterate(group: group, in: view) { (collection, key, object: T, index, stop) in
                block(tx, collection, key, object, index, &stop)
            }
        }
    }

    func find<T>(group: String?, in view: String?, where: (_ tx: YapDatabaseReadTransaction, _ object: inout T) -> Bool) -> T? {
        guard let group = group,
              let view = view
        else {
            return nil
        }

        var found: T? = nil

        read { tx in
            found = tx.find(group: group, in: view) { (object: inout T) in
                return `where`(tx, &object)
            }
        }

        return found
    }
}

extension YapDatabaseReadTransaction {

    func forView(_ name: String) -> YapDatabaseViewTransaction? {
        ext(name) as? YapDatabaseViewTransaction
    }

    func object<T>(for key: String?, in collection: String?) -> T? {
        guard let key = key else {
            return nil
        }

        return object(forKey: key, inCollection: collection) as? T
    }

    func object<T: Item>(for key: String?) -> T? {
        object(for: key, in: T.collection)
    }

    func iterate<T: Item>(using block: (_ key: String, _ object: T, _ stop: inout Bool) -> Void) {
        iterateKeysAndObjects(inCollection: T.collection, using: block)
    }

    func find<T: Item>(where: (T) -> Bool) -> T? {
        var found: T? = nil

        iterate { (key, object: T, stop) in
            if `where`(object) {
                found = object
                stop = true
            }
        }

        return found
    }

    func findAll<T: Item>(where: ((_ object: inout T) -> Bool)? = nil) -> [T] {
        var found = [T]()

        iterate { (key, object: T, stop) in
            var object = object

            if `where`?(&object) ?? true {
                found.append(object)
            }
        }

        return found
    }

    func iterate<T>(group: String?, in view: String?,
                 using block: (_ collection: String, _ key: String, _ object: T, _ index: Int, _ stop: inout Bool) -> Void)
    {
        guard let view = view,
              let group = group,
              let viewTx = forView(view)
        else {
            return
        }

        viewTx.iterateKeysAndObjects(inGroup: group) {
            collection, key, object, index, stop in

            if let object = object as? T {
                block(collection, key, object, index, &stop)
            }
        }
    }

    func find<T>(group: String?, in view: String?, where: (_ object: inout T) -> Bool) -> T? {
        var found: T? = nil

        iterate(group: group, in: view) { (collection, key, object: T, index, stop) in
            var object = object

            if `where`(&object) {
                found = object
                stop = true
            }
        }

        return found
    }

    func findAll<T>(group: String?, in view: String?, where: ((_ object: inout T) -> Bool)? = nil) -> [T] {
        var objects = [T]()

        iterate(group: group, in: view) { (collection, key, object: T, index, stop) in
            var object = object

            if `where`?(&object) ?? true {
                objects.append(object)
            }
        }

        return objects
    }
}

extension YapDatabaseReadWriteTransaction {

    func setObject<T: Item>(_ object: T) {
        setObject(object, forKey: object.id, inCollection: T.collection)
    }

    func remove<T: Item>(_ object: T) {
        removeObject(forKey: object.id, inCollection: T.collection)
    }
}

extension YapDatabaseViewMappings {

    func isNextSnapshot(_ notifications: [Notification]) -> Bool {
        guard snapshotOfLastUpdate < .max else {
            return false
        }

        let firstSnapshot = (notifications.first?.userInfo?[YapDatabaseSnapshotKey] as? NSNumber)?.uint64Value

        return snapshotOfLastUpdate + 1 == firstSnapshot
    }
}
