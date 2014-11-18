((factory) ->
    if typeof (window) == 'undefined'
        module.exports = factory(global.setTimeout)
    else
        window.$amd.util.timeout = factory(window.setTimeout)
)((setTimeout) ->
    return class $timeout
        constructor: (context, timeout, callback) ->
            if callback
                wrapper = () -> callback.call(context)
            else
                callback = timeout
                timeout = context
                wrapper = () -> callback()
            return setTimeout(wrapper, timeout)
)
