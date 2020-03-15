/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import CoreData

public final class StreamableProvider<T: Identifiable> {

    let source: AnyStreamableSource<T>
    let repository: AnyDataProviderRepository<T>
    let observable: AnyDataProviderRepositoryObservable<T>
    let operationManager: OperationManagerProtocol
    let processingQueue: DispatchQueue

    var observers: [DataProviderObserver<T, StreamableProviderObserverOptions>] = []

    public init(source: AnyStreamableSource<T>,
                repository: AnyDataProviderRepository<T>,
                observable: AnyDataProviderRepositoryObservable<T>,
                operationManager: OperationManagerProtocol,
                serialQueue: DispatchQueue? = nil) {
        self.source = source
        self.repository = repository
        self.observable = observable
        self.operationManager = operationManager

        if let currentProcessingQueue = serialQueue {
            self.processingQueue = currentProcessingQueue
        } else {
            self.processingQueue = DispatchQueue(
                label: "co.jp.streamableprovider.repository.queue.\(UUID().uuidString)",
                qos: .utility)
        }
    }

    private func startObservingSource() {
        observable.addObserver(self, deliverOn: processingQueue) { [weak self] (changes) in
            self?.notifyObservers(with: changes)
        }
    }

    private func stopObservingSource() {
        observable.removeObserver(self)
    }

    private func fetchHistory(completionBlock: ((Result<Int, Error>?) -> Void)?) {
        source.fetchHistory(runningIn: processingQueue,
                            commitNotificationBlock: completionBlock)
    }

    private func notifyObservers(with changes: [DataProviderChange<Model>]) {
        observers.forEach { (observerWrapper) in
            if observerWrapper.observer != nil {
                dispatchInQueueWhenPossible(observerWrapper.queue) {
                    observerWrapper.updateBlock(changes)
                }
            }
        }
    }

    private func notifyObservers(with error: Error) {
        observers.forEach { (observerWrapper) in
            if observerWrapper.observer != nil, observerWrapper.options.alwaysNotifyOnRefresh {
                dispatchInQueueWhenPossible(observerWrapper.queue) {
                    observerWrapper.failureBlock(error)
                }
            }
        }
    }

    private func notifyObservers(with fetchResult: Result<Int, Error>) {
        observers.forEach { (observerWrapper) in
            if observerWrapper.observer != nil, observerWrapper.options.alwaysNotifyOnRefresh {
                switch fetchResult {
                case .success(let count):
                    if count == 0 {
                        dispatchInQueueWhenPossible(observerWrapper.queue) {
                            observerWrapper.updateBlock([])
                        }
                    }
                case .failure(let error):
                    dispatchInQueueWhenPossible(observerWrapper.queue) {
                        observerWrapper.failureBlock(error)
                    }
                }
            }
        }
    }
}

extension StreamableProvider: StreamableProviderProtocol {
    public typealias Model = T

    public func refresh() {
        source.fetchHistory(runningIn: processingQueue) { [weak self] result in
            if let result = result {
                self?.notifyObservers(with: result)
            }
        }
    }

    public func fetch(offset: Int,
                      count: Int,
                      synchronized: Bool,
                      with completionBlock: @escaping (Result<[Model], Error>?) -> Void) -> BaseOperation<[Model]> {
        let operation = repository.fetchOperation(by: offset, count: count, reversed: false)

        operation.completionBlock = { [weak self] in
            if let result = operation.result,
                case .success(let models) = result,
                models.count < count {

                let completionBlock: (Result<Int, Error>?) -> Void = { (optionalResult) in
                    if let result = optionalResult {
                        self?.notifyObservers(with: result)
                    }
                }

                self?.fetchHistory(completionBlock: completionBlock)
            }

            completionBlock(operation.result)
        }

        if synchronized {
            operationManager.enqueue(operations: [operation], in: .sync)
        } else {
            operationManager.enqueue(operations: [operation], in: .transient)
        }

        return operation
    }

    public func addObserver(_ observer: AnyObject,
                            deliverOn queue: DispatchQueue,
                            executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                            failing failureBlock: @escaping (Error) -> Void,
                            options: StreamableProviderObserverOptions) {
        processingQueue.async {
            let operation: BaseOperation<[Model]>

            if options.initialSize > 0 {
                operation = self.repository.fetchOperation(by: 0, count: options.initialSize, reversed: false)
            } else {
                operation = self.repository.fetchAllOperation()
            }

            operation.completionBlock = {
                guard let result = operation.result else {
                    dispatchInQueueWhenPossible(queue) {
                        failureBlock(DataProviderError.dependencyCancelled)
                    }

                    return
                }

                switch result {
                case .success(let items):
                    self.processingQueue.async {

                        if self.observers.contains(where: { $0.observer === observer }) {
                            dispatchInQueueWhenPossible(queue) {
                                failureBlock(DataProviderError.observerAlreadyAdded)
                            }

                            return
                        }

                        let shouldObserveSource = self.observers.isEmpty

                        self.observers = self.observers.filter { $0.observer != nil }

                        let repositoryObserver = DataProviderObserver(observer: observer,
                                                                      queue: queue,
                                                                      updateBlock: updateBlock,
                                                                      failureBlock: failureBlock,
                                                                      options: options)
                        self.observers.append(repositoryObserver)

                        let updates = items.map { DataProviderChange<T>.insert(newItem: $0) }

                        dispatchInQueueWhenPossible(queue) {
                            updateBlock(updates)
                        }

                        if shouldObserveSource {
                            self.startObservingSource()
                        }
                    }
                case .failure(let error):
                    dispatchInQueueWhenPossible(queue) {
                        failureBlock(error)
                    }
                }
            }

            if options.waitsInProgressSyncOnAdd {
                self.operationManager.enqueue(operations: [operation], in: .sync)
            } else {
                self.operationManager.enqueue(operations: [operation], in: .transient)
            }
        }
    }

    public func removeObserver(_ observer: AnyObject) {
        processingQueue.async {
            let wasObservingSource = !self.observers.isEmpty
            self.observers = self.observers.filter { $0.observer != nil && $0.observer !== observer }

            if wasObservingSource, self.observers.isEmpty {
                self.stopObservingSource()
            }
        }
    }
}
