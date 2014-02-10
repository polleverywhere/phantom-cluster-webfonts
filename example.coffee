phantomCluster = require("./index")
cluster = require("cluster")

# Mapping of website URLs to their <title>s
WEBSITES = {
    "http://www.themuse.com/": "The Muse - Career advice and better job search",
    "http://www.themuse.com/companies": "Companies | The Muse",
    "http://www.themuse.com/jobs": "Jobs | The Muse",
    "http://www.themuse.com/developers": "The Muse - Career advice and better job search",
}

# Enqueues the requests
enqueueRequests = (engine) ->
    fulfilled = 0

    enqueuer = (request) ->
        item = engine.enqueue(request)

        # Fires when the item times out and has to be re-enqueued
        item.on "timeout", () ->
            console.log("# Queue item timed out, re-enqueueing #{item.id}")
            enqueuer(request)

        # Fires when there's a response for this item. Validate it.
        item.on "response", () ->
            console.log("# Response")
            if WEBSITES[item.request] != item.response then throw new Error("Unexpected response for #{item.request}: #{item.response}")

            fulfilled += 1
            if fulfilled == 16 then process.nextTick(() -> engine.stop())

    for i in [0...4]
        for key of WEBSITES
            enqueuer(key)

# The main callback
main = () ->
    # Start the engine
    engine = phantomCluster.createQueued({
        workers: 4,
        workerIterations: 4,
        workerParallelism: 2,
        phantomBasePort: 12345
    })

    # If this is the master, enqueue all the tasks
    if cluster.isMaster then enqueueRequests(engine)

    # Called when a worker starts up
    engine.on "workerStarted", (worker) -> console.log("# Worker started: " + worker.id)

    # Called when a worker dies
    engine.on "workerDied", (worker) -> console.log("# Worker died: " + worker.id)

    # Called when an engine starts (either a worker or master)
    engine.on "started", () -> console.log("# Started")

    # Called when an engine stops (either a worker or master)
    engine.on "stopped", () -> console.log("# Stopped")

    # Called when a phantom instance is started
    engine.on "phantomStarted", () -> console.log("# Phantom instance started")

    # Called when a phantom instance dies
    engine.on "phantomDied", () -> console.log("# Phantom instance died")

    # Called when there's a request URL to crawl
    engine.on "request", (page, item) ->
        console.log("# Ready to process #{item.request}")

        # Open the page, grab the title, and send a response with it
        @ph.createPage((page) =>
            page.open(item.request, (status) =>
                page.evaluate((() -> document.title), (result) =>
                    console.log("# Finished request for #{item.request}: #{result}")
                    item.finish(result)
                )
            )
        )
    
    engine.start()

main()
