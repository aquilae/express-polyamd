((factory) ->
    if typeof (window) == 'undefined'
        util = require('./util')
        util = util.extend({}, util, {
            delay: require('./delay'),
            timeout: require('./timeout')
        })
        return module.exports = factory(util)
    else
        window.$amd.q = factory(window.$amd.util)
)(($util) ->
    PENDING = 1
    RESOLVED = 2
    REJECTED = 3

    $$strstate = (state) ->
        return switch state
            when RESOLVED then 'resolved'
            when REJECTED then 'rejected'
            when PENDING then 'pending'
            else 'unknown'

    q = (options) ->
        return q.defer(options)

    q.$isObject = (obj) ->
        if obj == null then return false
        return switch typeof (obj)
            when 'undefined' then false
            when 'boolean' then false
            when 'number' then false
            when 'string' then false
            else true

    q.$clone = (obj) ->
        result = {}
        for own key, value of obj
            result[key] = value
        return result

    q.$swap = (current, next) ->
        return if next == undefined then current else next

    q.$unwrap = (value, resolved, rejected, state) ->
        succeeded = false
        $resolved = (cv) ->
            if not succeeded
                try
                    resolved(cv)
                catch err
                    rejected(err)
                succeeded = true
            return
        $rejected = (cv) ->
            if not succeeded
                try
                    rejected(cv)
                catch err
                    rejected(err)
                succeeded = true
            return
        try
            if q.$isObject(value) and $util.isFunction(fn = value['then'])
                fn.call(value, $resolved, $rejected)
                return
            else if state == RESOLVED
                $resolved(value)
                return
            else if state == REJECTED
                $rejected(value)
                return
        catch err
            $rejected(err)
            return
        throw new Error(
            "unknown state: #{state} (#{$$strstate(state)})")

    $$id = 0
    q.defer = (options) ->
        $id = $$id++
        $options = q.$clone(options)
        $state = PENDING
        $value = null
        $handlers = []

        $strstate = () -> return $$strstate($state)

        # this queue allows us to aggregate callbacks
        # that should be called on next event loop tick
        # preserving their order of execution
        $fnqueue = []
        $enqueue = (fn) ->
            $fnqueue.push(fn)
            if $fnqueue.length == 1
                $util.delay () ->
                    fnqueue = $fnqueue.slice(0)
                    $fnqueue.length = 0
                    fnqueue.forEach((fn) -> fn())

        $$hid = 0
        $then = (resolved, rejected) ->
            deferred = q.defer($options)

            $hid = $$hid++
            handler = (state, value) ->
                # first unwrap: raw value -> callback arg
                # second unwrap: callback arg -> deferred result
                # third unwrap: resolves or rejects deferred

                $resolved = (value) -> q.$unwrap(value, deferred.resolve, deferred.reject, RESOLVED)
                $rejected = (value) -> q.$unwrap(value, deferred.resolve, deferred.reject, REJECTED)

                $$resolved = (value) ->
                    if $util.isFunction(resolved)
                        $enqueue () ->
                            try
                                next = resolved(value)
                                if next == $promise or next == deferred.promise
                                    throw new TypeError("can not resolved promise with itself (#{$promise})")
                                value = q.$swap(value, next)
                                q.$unwrap(value, $resolved, $rejected, RESOLVED)
                            catch err
                                q.$unwrap(err, $resolved, $$rejected, REJECTED)
                    else
                        q.$unwrap(value, $resolved, $rejected, RESOLVED)
                $$rejected = (value) ->
                    if $util.isFunction(rejected)
                        $enqueue () ->
                            try
                                next = rejected(value)
                                if next == $promise or next == deferred.promise
                                    throw new TypeError("can not resolved promise with itself (#{$promise})")
                                value = q.$swap(value, next)
                                q.$unwrap(value, $resolved, $rejected, REJECTED)
                            catch err
                                q.$unwrap(err, $resolved, $rejected, REJECTED)
                    else
                        q.$unwrap(value, $resolved, $rejected, REJECTED)

                q.$unwrap(value, $$resolved, $$rejected, state)

            if $state == PENDING
                $handlers.push(handler)
            else
                handler($state, $value)

            return deferred.promise

        $promise = {
            then: $then
            toString: () -> "[object Promise(id: #{$id}; state: #{$strstate()}; value: #{try ('' + $value)}; #handlers: #{$handlers.length})]"
            debug: (name, log) ->
                resolved = (value) ->
                    log("#{name} resolved:", value)
                    return value
                rejected = (value) ->
                    log("#{name} rejected:", value)
                    return value
                return $promise.then(resolved, rejected)
        }

        $resolve = (value) ->
            if $state == PENDING
                $state = RESOLVED
                $value = value
                $handlers.forEach (handler) ->
                    handler($state, $value)
                return
                if $handlers.length > 0
                    for i in [$handlers.length-1..0]
                        $handlers[i]($state, value)
            else if not $options.graceful
                throw new Error(
                    "unable to resolve with #{value}:" +
                    " #{$strstate()} with #{value}")
            return $promise

        $reject = (value) ->
            if $state == PENDING
                $state = REJECTED
                $value = value
                $handlers.forEach (handler) ->
                    handler($state, $value)
                return
                if $handlers.length > 0
                    for i in [$handlers.length-1..0]
                        $handlers[i]($state, value)
            else if not $options.graceful
                throw new Error(
                    "unable to reject with #{value}:" +
                    " #{$strstate()} with #{value}")
            return $promise

        $deferred = {
            promise: $promise
            resolve: $resolve
            reject: $reject
            toString: () -> "[object Deferred(id: #{$id}; state: #{$strstate()}; value: #{$value})]"
        }

        return $deferred

    q.resolve = (value) ->
        deferred = q.defer()
        deferred.resolve(value)
        return deferred.promise

    q.reject = (value) ->
        deferred = q.defer()
        deferred.reject(value)
        return deferred.promise

    q.when = (value) ->
        return q.resolve(value)

    q.all = (promises) ->
        return if $util.isArray(promises)
            q.all.list(promises)
        else
            q.all.hash(promises)

    q.all.list = (promises) ->
        deferred = q.defer()
        if not promises
            deferred.resolve([])
        else
            remaining = promises.length
            if remaining == 0
                deferred.resolve([])
            else
                rejected = (value) ->
                    if remaining > 0
                        remaining = -Infinity
                        deferred.reject(value)
                    return
                values = []
                values.length = remaining
                for index in [0...promises.length]
                    ((index) ->
                        resolved = (value) ->
                            if remaining > 0
                                values[index] = value
                                if --remaining == 0
                                    remaining = -Infinity
                                    deferred.resolve(values)
                            return
                        promise = q.when(promises[index])
                        promise.then(resolved, rejected)
                    )(index)
        return deferred.promise

    q.all.hash = (promises) ->
        deferred = q.defer()
        if not promises
            deferred.resolve({})
        else
            keys = Object.getOwnPropertyNames(promises)
            remaining = keys.length
            if remaining == 0
                deferred.resolve({})
            else
                values = {}
                rejected = (value) ->
                    if remaining > 0
                        remaining = -Infinity
                        deferred.reject(value)
                    return
                for key in keys
                    ((key) ->
                        resolved = (value) ->
                            if remaining > 0
                                values[key] = value
                                if --remaining == 0
                                    remaining = -Infinity
                                    deferred.resolve(values)
                            return
                        promise = q.when(promises[key])
                        promise.then(resolved, rejected)
                    )(key)
        return deferred.promise

    q.TimeoutError = class TimeoutError
        constructor: () -> super("promise timed out")
    q.TimeoutError = $util.makeError class TimeoutError
        constructor: () ->
            Error.call(this)
            if $util.isFunction(Error.captureStackTrace)
                Error.captureStackTrace(this, arguments.callee)

            this.name = 'TimeoutError'
            this.message = 'promise timed out'

            return

    return q
)

