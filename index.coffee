phantom = require("phantom")
cluster = require("cluster")
events = require("events")
zmq = require("zmq")

DEFAULT_WORKER_ITERATIONS = 100
STOP_QUEUE_CHECKING_INTERVAL = 10
DEFAULT_MESSAGE_TIMEOUT = 60 * 1000
POLL_QUEUE_ITEM_INTERVAL = 10
DEFAULT_ZMQ_CONNECTION_STRING = "ipc:///tmp/phantom-cluster"

empty = (obj) ->
    for key of obj
        return false
    return true

create = (options) ->
    if cluster.isMaster
        new PhantomClusterServer(options)
    else
        new PhantomClusterClient(options)

createQueued = (options) ->
    if cluster.isMaster
        new PhantomQueuedClusterServer(options)
    else
        new PhantomQueuedClusterClient(options)

class PhantomClusterServer extends events.EventEmitter
    constructor: (options) ->
        super
        @numWorkers = options.workers or require("os").cpus().length
        @workers = {}
        @done = false

    addWorker: () ->
        worker = cluster.fork()
        @workers[worker.id] = worker
        @emit("workerStarted", worker)

    start: () ->
        cluster.on "exit", (worker, code, signal) =>
            @emit("workerDied", worker, code, signal)
            delete @workers[worker.id]
            if not @done then @addWorker()

        for i in [0...this.numWorkers]
            @addWorker()

        @emit("started")

    stop: () ->
        if not @done
            @done = true

            for _, worker of @workers
                worker.kill()

            @emit("stopped")

class PhantomClusterClient extends events.EventEmitter
    constructor: (options) ->
        super
        @ph = null
        @iterations = options.workerIterations or DEFAULT_WORKER_ITERATIONS
        @phantomArguments = options.phantomArguments or []
        @phantomBinary = options.phantomBinary or require("phantomjs").path
        @phantomBasePort = this.phantomBasePort or 12300
        @done = false

    start: () ->
        options = {
            binary: @phantomBinary,
            port: @phantomBasePort + cluster.worker.id + 1,
            onExit: () =>
                @emit("phantomDied")
                @stop()
        }

        onStart = (ph) =>
            @ph = ph
            @emit("phantomStarted")
            @next()

        phantom.create.apply(phantom, @phantomArguments.concat([options, onStart]))
        @emit("started")

    next: () ->
        if not @done
            @iterations--

            if @iterations >= 0
                @emit("workerReady")
            else
                @stop()

    stop: () ->
        if not @done
            @done = true
            @emit("stopped")
            process.nextTick(() -> process.exit(0))

class PhantomQueuedClusterServer extends PhantomClusterServer
    constructor: (options) ->
        super options

        @zmqConnectionString = options.zmqConnectionString or DEFAULT_ZMQ_CONNECTION_STRING
        @messageTimeout = options.messageTimeout or DEFAULT_MESSAGE_TIMEOUT
        @_sentMessages = {}
        @_messageIdCounter = 0
        @_stopCheckingInterval = null
        @queue = []

        @_socket = zmq.socket("rep")
        @_socket.bindSync(@zmqConnectionString)
        @_socket.on "message", @_onSocketMessage

        @on "started", @_onStart
        @on "stopped", @_onStop

    enqueue: (request) ->
        item = new QueueItem(@_messageIdCounter++, request)

        item.on "timeout", () =>
            delete @_sentMessages[item.id]
            @enqueue(request)

        @queue.push(item)
        item

    _onStart: () =>
        @_stopCheckingInterval = setInterval(() =>
            if not @done and @queue.length == 0 and empty(@_sentMessages) then @stop()
        , STOP_QUEUE_CHECKING_INTERVAL)

    _onStop: () =>
        if @_stopCheckingInterval != null then clearInterval(@_stopCheckingInterval)
        @_socket.close()

    _onSocketMessage: (message) =>
        json = JSON.parse(message.toString())

        if json.action == "queueItemRequest"
            if @queue.length > 0
                item = @queue.shift()
                item.start(@messageTimeout)

                @_socket.send(JSON.stringify({
                    action: "queueItemRequest",
                    id: item.id,
                    request: item.request
                }))
                
                @_sentMessages[item.id] = item
            else
                @_socket.send(JSON.stringify({
                    action: "done"
                }))
        else if json.action == "queueItemResponse"
            item = @_sentMessages[json.id]

            if item
                item.finish(json.response)
                delete @_sentMessages[json.id]

                @_socket.send(JSON.stringify({
                    action: "OK"
                }))
            else
                @_socket.send(JSON.stringify({
                    action: "ignored"
                }))

class PhantomQueuedClusterClient extends PhantomClusterClient
    constructor: (options) ->
        super options

        @zmqConnectionString = options.zmqConnectionString or DEFAULT_ZMQ_CONNECTION_STRING
        
        @currentRequestId = null
        @_socket = zmq.socket("req")
        @_socket.connect(@zmqConnectionString)
        @_socket.on "message", @_onSocketMessage

        @on "stopped", @_onStop
        @on "workerReady", @_onPhantomStarted

    queueItemResponse: (response) ->
        @_socket.send(JSON.stringify({
            action: "queueItemResponse",
            id: @currentRequestId,
            response: response
        }))

        @next()

    _onStop: () =>
        @_socket.close()

    _onSocketMessage: (message) =>
        json = JSON.parse(message.toString())

        if json.action == "queueItemRequest"
            @currentRequestId = json.id
            @emit("queueItemReady", json.request)
        else if json.action == "queueItemResponse"
            if json.status not in ["OK", "ignored"]
                throw new Error("Unexpected status code from queueItemResponse message: #{json.status}")
        else if json.action == "done"
            @stop()

    _onPhantomStarted: () =>
        @_socket.send(JSON.stringify({
            action: "queueItemRequest"
        }))

class QueueItem extends events.EventEmitter
    constructor: (id, request, timeout) ->
        @id = id
        @request = request
        @response = null
        @timeout = null

    start: (timeout) ->
        @timeout = setTimeout(@_timeout, timeout)

    finish: (response) ->
        if @timeout then clearTimeout(@timeout)
        @response = response
        @emit("response")

    _timeout: () =>
        @emit("timeout")

exports.create = create
exports.createQueued = createQueued
exports.PhantomClusterServer = PhantomClusterServer
exports.PhantomClusterClient = PhantomClusterClient
exports.PhantomQueuedClusterServer = PhantomQueuedClusterServer
exports.PhantomQueuedClusterClient = PhantomQueuedClusterClient
