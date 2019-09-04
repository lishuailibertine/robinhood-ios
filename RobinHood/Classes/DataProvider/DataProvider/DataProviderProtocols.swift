/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol DataProviderProtocol {
    associatedtype Model: Identifiable

    var executionQueue: OperationQueue { get }

    func fetch(by modelId: String, completionBlock: ((Result<Model?, Error>?) -> Void)?) -> BaseOperation<Model?>

    func fetch(page index: UInt, completionBlock: ((Result<[Model], Error>?) -> Void)?) -> BaseOperation<[Model]>

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue?,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void,
                     options: DataProviderObserverOptions)

    func removeObserver(_ observer: AnyObject)

    func refresh()
}

public extension DataProviderProtocol {
    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue?,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void) {
        addObserver(observer,
                    deliverOn: queue,
                    executing: updateBlock,
                    failing: failureBlock,
                    options: DataProviderObserverOptions())
    }
}

public protocol DataProviderSourceProtocol {
    associatedtype Model: Identifiable

    func fetchOperation(by modelId: String) -> BaseOperation<Model?>

    func fetchOperation(page index: UInt) -> BaseOperation<[Model]>
}
