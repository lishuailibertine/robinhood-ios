import XCTest
@testable import RobinHood

class DataProviderTests: DataProviderBaseTests {
    let cache: CoreDataCache<FeedData, CDFeed> = createDefaultCoreDataCache()

    override func setUp() {
        try! clearDatabase(using: cache.databaseService)
    }

    override func tearDown() {
        try! clearDatabase(using: cache.databaseService)
    }

    func testSynchronizationOnInit() {
        // given
        let objects = (0..<10).map { _ in createRandomFeed() }
        let trigger = DataProviderEventTrigger.onInitialization
        let source = createDataSourceMock(base: self, returns: objects)
        let dataProvider = DataProvider<FeedData, CDFeed>(source: source,
                                                          cache: cache,
                                                          updateTrigger: trigger)

        let expectation = XCTestExpectation()

        var optionalChanges: [DataProviderChange<FeedData>]?

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            optionalChanges = changes
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        guard let changes = optionalChanges else {
            XCTFail()
            return
        }

        XCTAssertEqual(changes.count, objects.count)

        for change in changes {
            switch change {
            case .insert(let newItem):
                XCTAssertTrue(objects.contains(newItem))
            default:
                XCTFail()
            }
        }
    }

    func testSynchronizationOnObserverAdd() {
        // given
        let projects = (0..<10).map { _ in createRandomFeed() }
        let trigger = DataProviderEventTrigger.onAddObserver
        let source = createDataSourceMock(base: self, returns: projects)
        let dataProvider = DataProvider<FeedData, CDFeed>(source: source,
                                                          cache: cache,
                                                          updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        guard allChanges.count == 2 else {
            XCTFail()
            return
        }

        XCTAssertTrue(allChanges[0].isEmpty)

        XCTAssertEqual(allChanges[1].count, projects.count)

        for change in allChanges[1] {
            switch change {
            case .insert(let newItem):
                XCTAssertTrue(projects.contains(newItem))
            default:
                XCTFail()
            }
        }
    }

    func testFetchByIdFromCache() {
        // given
        let projects = (0..<10).map { _ in createRandomFeed() }
        let trigger = DataProviderEventTrigger.onInitialization
        let source = createDataSourceMock(base: self, returns: projects)
        let dataProvider = DataProvider<FeedData, CDFeed>(source: source,
                                                          cache: cache,
                                                          updateTrigger: trigger)

        let changeExpectation = XCTestExpectation()

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            changeExpectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock)

        wait(for: [changeExpectation], timeout: Constants.expectationDuration)

        // then
        let optionalResult = fetchById(projects[0].identifier, from: dataProvider)

        guard let result = optionalResult, case .success(let fetchedProject) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(fetchedProject, projects[0])
    }

    func testFetchAllFromCache() {
        // given
        let trigger = DataProviderEventTrigger.onInitialization
        let source = createDataSourceMock(base: self, returns: [FeedData]())
        let dataProvider = DataProvider<FeedData, CDFeed>(source: source,
                                                          cache: cache,
                                                          updateTrigger: trigger)

        // when
        let optionalBeforeResult = fetch(page: 0, from: dataProvider)

        // then
        guard let beforeResult = optionalBeforeResult, case .success(let beforeFetchedProjects) = beforeResult else {
            XCTFail()
            return
        }

        XCTAssertTrue(beforeFetchedProjects.isEmpty)

        // when
        let saveExpectation = XCTestExpectation()

        let projects = (0..<10).map { _ in createRandomFeed() }
        cache.save(updating:projects, deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let optionalAfterResult = fetch(page: 0, from: dataProvider)

        // then
        guard let afterResult = optionalAfterResult, case .success(let afterFetchedProjects) = afterResult else {
            XCTFail()
            return
        }

        XCTAssertEqual(afterFetchedProjects.count, projects.count)

        for fetchedProject in afterFetchedProjects {
            XCTAssertTrue(projects.contains(fetchedProject))
        }
    }

    func testManualSynchronization() {
        let objects = (0..<10).map { _ in createRandomFeed() }
        let trigger = DataProviderEventTrigger.onNone
        let source = createDataSourceMock(base: self, returns: objects)
        let dataProvider = DataProvider<FeedData, CDFeed>(source: source,
                                                          cache: cache,
                                                          updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock)

        dataProvider.refreshCache()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        guard allChanges.count == 2 else {
            XCTFail()
            return
        }

        XCTAssertTrue(allChanges[0].isEmpty)

        XCTAssertEqual(allChanges[1].count, objects.count)

        for change in allChanges[1] {
            switch change {
            case .insert(let newItem):
                XCTAssertTrue(objects.contains(newItem))
            default:
                XCTFail()
            }
        }
    }

    func testInsertUpdateDeleteChangesAtOnce() {
        // given
        let saveExpectation = XCTestExpectation()

        var objects = (0..<10).map { _ in createRandomFeed() }
        cache.save(updating: objects, deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let removedIdentifier = objects.last!.identifier
        objects.removeLast()

        objects[0].name = UUID().uuidString
        let updatedObject = objects[0]

        let insertedObject = createRandomFeed()
        objects.append(insertedObject)

        // when
        let trigger = DataProviderEventTrigger.onAddObserver
        let source = createDataSourceMock(base: self, returns: objects)
        let dataProvider = DataProvider<FeedData, CDFeed>(source: source,
                                                          cache: cache,
                                                          updateTrigger: trigger)

        var allChanges: [[DataProviderChange<FeedData>]] = []

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        var insertCount = 0
        var updateCount = 0
        var deleteCount = 0

        for change in allChanges[1] {
            switch change {
            case .insert(let newItem):
                XCTAssertEqual(insertedObject, newItem)
                insertCount += 1
            case .update(let item):
                XCTAssertEqual(updatedObject, item)
                updateCount += 1
            case .delete(let identifier):
                XCTAssertEqual(removedIdentifier, identifier)
                deleteCount += 1
            }
        }

        XCTAssertEqual(insertCount, 1)
        XCTAssertEqual(updateCount, 1)
        XCTAssertEqual(deleteCount, 1)
    }

    func testDataProviderSuccessWithAlwaysNotifyOption() {
        // given
        let saveExpectation = XCTestExpectation()

        let objects = (0..<10).map { _ in createRandomFeed() }
        cache.save(updating: objects, deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let trigger = DataProviderEventTrigger.onNone
        let source = createDataSourceMock(base: self, returns: objects)
        let dataProvider = DataProvider<FeedData, CDFeed>(source: source,
                                                                cache: cache,
                                                                updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        let observerOptions = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)

        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock,
                                      options: observerOptions)

        // when
        dataProvider.refreshCache()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        XCTAssertEqual(allChanges[0].count, objects.count)

        for change in allChanges[0] {
            switch change {
            case .insert(let newItem):
                XCTAssertTrue(objects.contains(newItem))
            default:
                XCTFail()
            }
        }

        XCTAssertEqual(allChanges[1].count, 0)
    }

    func testDataProviderFailWithAlwaysNotifyOption() {
        // given

        let saveExpectation = XCTestExpectation()

        let objects = (0..<10).map { _ in createRandomFeed() }
        cache.save(updating: objects, deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let trigger = DataProviderEventTrigger.onNone
        let source: AnyDataProviderSource<FeedData> = createDataSourceMock(base: self,
                                                                           returns: NetworkBaseError.unexpectedResponseObject)
        let dataProvider = DataProvider<FeedData, CDFeed>(source: source,
                                                          cache: cache,
                                                          updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []
        var receivedError: Error?

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            receivedError = error
            expectation.fulfill()
            return
        }

        let observerOptions = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)

        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock,
                                      options: observerOptions)

        // when

        dataProvider.refreshCache()

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        // then

        XCTAssertNotNil(receivedError)

        guard allChanges.count == 1 else {
            XCTFail()
            return
        }

        guard allChanges[0].count == objects.count else {
            XCTFail()
            return
        }

        for change in allChanges[0] {
            switch change {
            case .insert(let newItem):
                XCTAssertTrue(objects.contains(newItem))
            default:
                XCTFail()
            }
        }
    }
}
