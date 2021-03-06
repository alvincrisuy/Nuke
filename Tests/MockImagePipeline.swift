// The MIT License (MIT)
//
// Copyright (c) 2015-2018 Alexander Grebenyuk (github.com/kean).

import Foundation
@testable import Nuke

private class _MockImageTask: ImageTask {
    fileprivate var _cancel: () -> Void = {}

    init(request: ImageRequest, pipeline: ImagePipeline) {
        super.init(taskId: 0, request: request, pipeline: pipeline)
    }

    override func cancel() {
        _cancel()
    }
}

class MockImagePipeline: ImagePipeline {
    static let DidStartTask = Notification.Name("com.github.kean.Nuke.Tests.MockLoader.DidStartTask")
    static let DidCancelTask = Notification.Name("com.github.kean.Nuke.Tests.MockLoader.DidCancelTask")
    
    var createdTaskCount = 0
    let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    var results = [URL: Result<Image>]()
    var ignoreCancellation = false

    override init(configuration: ImagePipeline.Configuration = ImagePipeline.Configuration()) {
        var conf = configuration
        conf.imageCache = nil // Disabla caching
        super.init(configuration: conf)
    }

    override func loadImage(with request: ImageRequest, completion: @escaping ImageTask.Completion) -> ImageTask {
        let task = _MockImageTask(request: request, pipeline: self)

        NotificationCenter.default.post(name: MockImagePipeline.DidStartTask, object: self)

        createdTaskCount += 1

        let operation = BlockOperation() {
            DispatchQueue.main.async {
                let result = self.results[request.urlRequest.url!] ?? .success(defaultImage)
                _ = task // Retain task until it's finished (matches ImagePipeline behavior)
                completion(result)
            }
        }
        self.queue.addOperation(operation)

        if !self.ignoreCancellation {
            task._cancel = {
                operation.cancel()
                NotificationCenter.default.post(name: MockImagePipeline.DidCancelTask, object: self)
            }
        }

        return task
    }
}
