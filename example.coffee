phantomCluster = require("./index")
cluster = require("cluster")

# Mapping of website URLs to their <title>s. Limited set of websites so that
# we're constraints to places we know are cool with getting a wee little
# phantomjs crawl.
WEBSITES = {
    "http://www.themuse.com/": "The Muse - Career advice and better job search",
    "http://www.themuse.com/companies": "Companies | The Muse",
    "http://www.themuse.com/jobs": "Jobs | The Muse",
    "http://www.themuse.com/developers": "The Muse - Career advice and better job search",
}

addItemListeners = (item) ->
    item.on "timeout", () -> console.log("# Queue item timed out, re-enqueueing #{item.id}")

    item.on "response", () ->
        console.log("# Response")
        if WEBSITES[item.request] != item.response then throw new Error("Unexpected response for #{item.request}: #{item.response}")

main = () ->
    engine = phantomCluster.createQueued({
        workers: 4,
        workerIterations: 4,
        phantomBasePort: 90222
    })

    if cluster.isMaster
        for i in [0...4]
            for key of WEBSITES
                addItemListeners(engine.enqueue(key))

    engine.on "workerStarted", (worker) -> console.log("# Worker started: " + worker.id)
    engine.on "workerDied", (worker) -> console.log("# Worker died: " + worker.id)
    engine.on "started", () -> console.log("# Started")
    engine.on "stopped", () -> console.log("# Stopped")
    engine.on "phantomStarted", () -> console.log("# Phantom instance started")
    engine.on "phantomDied", () -> console.log("# Phantom instance died")

    engine.on "queueItemReady", (url) ->
        @ph.createPage((page) =>
            page.open(url, (status) =>
                page.evaluate((() -> document.title), (result) =>
                    console.log("# Finished request for #{url}: #{result}")
                    @queueItemResponse(result)
                )
            )
        )
    
    engine.start()

main()
