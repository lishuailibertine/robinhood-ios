/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import RobinHood
import CoreData

func createDataSourceMock<T>(base: Any, returns items: [T], after delay: TimeInterval = 0.0) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> BaseOperation<[T]> = { _ in
        return ClosureOperation {
            usleep(useconds_t(delay * 1e+6))
            return items
        }
    }

    let fetchByIdBlock: (String) -> BaseOperation<T?> = { _ in
        return ClosureOperation {
            usleep(useconds_t(delay * 1e+6))
            return nil
        }
    }

    return AnyDataProviderSource(base: base,
                                 fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createDataSourceMock<T>(base: Any, returns error: Error) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> BaseOperation<[T]> = { _ in
        let pageOperation = BaseOperation<[T]>()
        pageOperation.result = .failure(error)

        return pageOperation
    }

    let fetchByIdBlock: (String) -> BaseOperation<T?> = { _ in
        let identifierOperation = BaseOperation<T?>()
        identifierOperation.result = .failure(error)

        return identifierOperation
    }

    return AnyDataProviderSource(base: base,
                                 fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createSingleValueSourceMock<T>(base: Any, returns item: T, after delay: TimeInterval = 0.0) -> AnySingleValueProviderSource<T> {
    let fetch: () -> BaseOperation<T> = {
        return ClosureOperation {
            usleep(useconds_t(delay * 1e+6))
            return item
        }
    }

    return AnySingleValueProviderSource(base: base,
                                        fetch: fetch)
}

func createSingleValueSourceMock<T>(base: Any, returns error: Error) -> AnySingleValueProviderSource<T> {
    let fetch: () -> BaseOperation<T> = {
        let operation = BaseOperation<T>()
        operation.result = .failure(error)

        return operation
    }

    return AnySingleValueProviderSource(base: base,
                                        fetch: fetch)
}

func createStreamableSourceMock<T: Identifiable, U: NSManagedObject>(base: Any,
                                                                     repository: CoreDataRepository<T, U>,
                                                                     operationQueue: OperationQueue,
                                                                     returns items: [T]) -> AnyStreamableSource<T> {
    let source: AnyStreamableSource<T> = AnyStreamableSource(source: base) { (offset, count, queue, completionBlock) in
        let dispatchQueue = queue ?? .main

        let saveOperation = repository.saveOperation( { items }, { [] })

        operationQueue.addOperation(saveOperation)

        dispatchQueue.async {
            completionBlock?(.success(items.count))
        }
    }

    return source
}

func createStreamableSourceMock<T: Identifiable>(base: Any, returns error: Error) -> AnyStreamableSource<T> {
    let source: AnyStreamableSource<T> = AnyStreamableSource(source: base) { (offset, count, queue, completionBlock) in
        let dispatchQueue = queue ?? .main

        dispatchQueue.async {
            completionBlock?(.failure(error))
        }
    }

    return source
}
