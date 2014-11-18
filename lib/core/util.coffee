((factory) ->
    if typeof (window) == 'undefined'
        module.exports = factory()
    else
        if not window.$amd then window.$amd = {}
        window.$amd.util = factory()
)(() ->
    util = {}

    util.isString = (obj) ->
        return typeof (obj) == 'string'

    util.isFunction = (obj) ->
        return typeof (obj) == 'function'

    util.isArray = if util.isFunction(Array.isArray)
        (obj) -> return Array.isArray(obj)
    else
        (obj) ->
            if obj instanceof Array then return true
            return Object.prototype.toString.call(obj) == '[object Array]'

    util.extend = (target, sources...) ->
        for source in sources
            for own key, value of source
                target[key] = value
        return target

    util.makeError = (ctor, superCtor) ->
        if not superCtor then superCtor = Error
        ctor.super_ = superCtor
        ctor.prototype = Object.create superCtor.prototype, {
            constructor: {
                value: ctor
                enumerable: false
                writable: true
                configurable: true
            }
            log: {
                value: (log) ->
                    log(this.stack or "#{if this.name then this.name + ': '}#{this.message}")
                    if this.cause
                        if stack = this.cause.stack
                            log('this exception was caused by:')
                            if util.isFunction(this.cause.log)
                                this.cause.log(log)
                            else
                                log(stack)
                        else if this.cause.message
                            prefix = 'this exception was caused by: '
                            name = if this.cause.name then this.cause.name + ': ' else ''
                            log("#{prefix}#{name}#{this.cause.message}")
                        else
                            log("this exception was caused by:", this.cause)
                    return this
                enumerable: false
                writable: true
                configurable: false
            }
        }
        return ctor

    return util
)
