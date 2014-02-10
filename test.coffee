phantomCluster = require("./index")
cluster = require("cluster")

WEBSITES = {
    "http://www.themuse.com/": "The Muse - Career advice and better job search",
    "http://www.themuse.com/companies": "Companies | The Muse",
    "http://www.themuse.com/jobs": "Jobs | The Muse",
}

objectLength = (obj) ->
    count = 0
    for _ of obj
        count++
    return count

exports.testPhantomClusterServer = (test) ->
    test.expect(6)

    s = new phantomCluster.PhantomClusterServer({
        workers: 4
    })

    test.equal(s.numWorkers, 4)
    test.equal(objectLength(s.workers), 0)
    test.equal(s.done, false)

    s.start()
    test.equal(objectLength(s.workers), 4)
    test.equal(s.done, false)

    # Second stop should have no effect
    s.stop()
    s.stop()
    test.equal(s.done, true)
    test.done()

exports.testPhantomClusterWorker = (test) ->
    test.expect(7)

    # Mock for tests
    cluster.worker = {
        id: 1,
        workerParallelism: 2
    }

    c = new phantomCluster.PhantomClusterWorker({})

    test.equal(c.ph, null)
    test.equal(c.done, false)

    c.on("started", () -> test.ok(true))
    
    c.on("phantomStarted", () ->
        test.notEqual(c.ph, null)
        test.equal(c.iterations, 100)
        c.next()
        test.equal(c.iterations, 99)

        # Make sure .next() is called implicitly once (based on
        # `workerParallelism`) on phantom start
        setTimeout(() ->
            test.equal(c.iterations, 98)
            test.done()
        , 0)
    )

    c.start()

exports.testQueueItem = (test) ->
    test.expect(12)

    # QueueItem that times out. Also check various properties.
    i1 = new phantomCluster.QueueItem(1, {foo: true})
    test.equal(i1.id, 1)
    test.deepEqual(i1.request, {foo: true})
    test.equal(i1.timeout, null)
    test.equal(i1.state, 0)

    i1.on("response", () -> test.ok(false, "i1 should not respond"))

    i1.on("timeout", () ->
        test.ok(true, "i1 should time out")

        # QueueItem that responds
        i2 = new phantomCluster.QueueItem(2, {foo: false})

        i2.on("response", () ->
            test.equal(i2.state, 2)
            test.equal(i2.response, "yep")
            test.equal(i2.timeout, null)
        )
        
        i2.on("timeout", () ->
            test.ok(false, "i2 should not time out")
        )

        # Start i2
        i2.start(1000)
        i2.finish("yep")

        # Make sure we can't stop twice
        test.throws(() -> i2.finish("nope"))
        test.done()
    )

    # Make sure we can't finish without starting first
    test.throws(() -> i1.finish("nope"))

    # start i1
    i1.start(1000)
    test.equal(i1.state, 1)

    # Make sure we can't start twice
    test.throws(() -> i1.start(1000))
