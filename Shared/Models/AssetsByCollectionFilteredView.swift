//
//  AssetsByCollectionFilteredView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 A child view of `AssetsByCollectionView` which can filter that by project.

 Use `updateFilter(:)` to engage filtering.
 */
class AssetsByCollectionFilteredView: YapDatabaseFilteredView {

    static let name = "assets_by_collection_filtered"

    /**
     A mapping which reverse sorts the groups by creation date of the collection
     they represent, due to the specific construction of the group key.

      See `AssetsByCollectionView#groupKey(for:)` for reference.
    */
    static var mappings: YapDatabaseViewMappings {
        return YapDatabaseViewMappings(
            groupFilterBlock: { group, transaction in
                return true
        },
            sortBlock: { group1, group2, transaction in
                return group2.compare(group1)
        },
            view: name)
    }

    override init() {
        super.init(parentViewName: AssetsByCollectionView.name,
                   filtering: AssetsByCollectionFilteredView.getFilter(),
                   versionTag: nil, options: nil)
    }

    /**
     Update filter to a new `projectId`.

     - parameter projectId: The project ID to filter by.
        `nil` will disable the filter and show all entries.
    */
    class func updateFilter(_ projectId: String? = nil) {
        Db.writeConn?.asyncReadWrite { transaction in
            (transaction.ext(name) as? YapDatabaseFilteredViewTransaction)?
                .setFiltering(getFilter(projectId), versionTag: UUID().uuidString)
        }
    }

    /**
     - parameter projectId: The project ID to filter by.
     `nil` will disable the filter and show all entries.
     - returns: a filter block using the given projectId as criteria.
     */
    private class func getFilter(_ projectId: String? = nil) -> YapDatabaseViewFiltering {
        return YapDatabaseViewFiltering.withKeyBlock { transaction, group, collection, key in
            let groupProjectId = AssetsByCollectionView.projectId(from: group)

            return projectId == nil || groupProjectId == projectId
        }
    }
}
