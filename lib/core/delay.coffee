(() ->
    if typeof (window) == 'undefined'
        # server
        return module.exports = class $delay
            constructor: (callback) ->
                process.nextTick(callback)
                return null
    else
        # browser
        window.$amd.util.delay = ((window, document, html, util) ->
            canUseSetImmediateImplementation = () ->
                return util.isFunction(window.setImmediate)

            canUsePostMessageImplementation = () ->
                if not window.postMessage
                    return false
                if window.importScripts
                    return false
                flag = true
                $onmessage = window.onmessage
                window.onmessage = () -> flag = false
                window.postMessage("", "*");
                window.onmessage = $onmessage;
                return flag;

            canUseReadyStateChangeImplementation = () ->
                return html and 'onreadystatechange' in document.createElement('script')

            setImmediateImplementation = () ->
                return class $delay
                    constructor: (callback) ->
                        window.setImmediate(callback)
                        return null

            postMessageImplementation = () ->
                callbacks = {}
                index = 0

                handler = (event) ->
                    if event.source == window
                        if util.isString(event.data)
                            if event.data.substr(0, 6) == 'delay#'
                                if callback = callbacks[+event.data.substr(6)]
                                    delete callbacks[+event.data.substr(6)]
                                    callback()

                if window.addEventListener
                    window.addEventListener('message', handler, false)
                else
                    window.attachEvent('onmessage', handler)

                return class $delay
                    constructor: (callback) ->
                        callbacks[index] = callback
                        window.postMessage('delay#' + index++, '*')
                        return null

            readyStateChangeImplementation = () ->
                return class $delay
                    constructor: (callback) ->
                        script = document.createElement('script')
                        script.onreadystatechange = () ->
                            script.onreadystatechange = null
                            html.removeChild(script)
                            script = null
                            callback()
                        document.appendChild(script)
                        return null

            setTimeoutImplementation = () ->
                return (callback) -> window.setTimeout(callback, 0)

            return switch
                when canUseSetImmediateImplementation()
                    setImmediateImplementation()
                when canUsePostMessageImplementation()
                    postMessageImplementation()
                when canUseReadyStateChangeImplementation()
                    readyStateChangeImplementation()
                else
                    setTimeoutImplementation()
        )(window, document, document.documentElement or document, window.$amd.util)
)()
