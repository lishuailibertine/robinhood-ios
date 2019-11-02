/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Protocol that describes any unique identifiable instance.
 */

public protocol Identifiable {

    /// Unique identifier of the instance.

    var identifier: String { get }
}

/**
 *  Enum is designed to store changes introduced by data provider.
 */

public enum DataProviderChange<T> {
    /// New items has been added.
    /// Item is passed as associated value.
    case insert(newItem: T)

    /// Existing item has been updated
    /// Item is passed as associated value.
    case update(newItem: T)

    /// Existing item has been removed.
    /// Identifier of the item is passed as associated value.
    case delete(deletedIdentifier: String)

    /// Returns item if bounded as associated value.

    var item: T? {
        switch self {
        case .insert(let newItem):
            return newItem
        case .update(let newItem):
            return newItem
        default:
            return nil
        }
    }
}

/**
 *  Struct designed to store options needed to describe how an observer should be handled by data provider.
 */

public struct DataProviderObserverOptions {
    /// Asks data provider to notify observer in any case after synchronization completes.
    /// If this value is `false` (default value) then observer is only notified when
    /// there are changes after synchronization.
    public var alwaysNotifyOnRefresh: Bool

    /// Asks data provider to wait until any in progress synchronization completes before adding the observer.
    /// By default the value is `true`.
    /// - note: Passing `false` may significantly improve performance however may also introduce inconsitency between
    /// observer's local data and persistent data if a repository doesn't have any synchronization mechanism.
    public var waitsInProgressSyncOnAdd: Bool

    /// - parameters:
    ///    - alwaysNotifyOnRefresh: Asks data provider to notify observer in any case after synchronization completes.
    ///    Default value is `false`.
    ///
    ///    - waitsInProgressSyncOnAdd: Asks data provider to wait until any in progress synchronization
    ///    completes before adding the observer. Default value is `true`. Passing `false` may significantly
    ///    improve performance however may also introduce inconsitency between observer's local data and
    ///    persistent data if a repository doesn't have any synchronization mechanism.

    public init(alwaysNotifyOnRefresh: Bool = false,
                waitsInProgressSyncOnAdd: Bool = true) {
        self.alwaysNotifyOnRefresh = alwaysNotifyOnRefresh
        self.waitsInProgressSyncOnAdd = waitsInProgressSyncOnAdd
    }
}
