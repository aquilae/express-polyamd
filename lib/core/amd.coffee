(() ->
    LOAD_TIMEOUT = 200

    if typeof (window) == 'undefined'
        # server
        return module.exports = (() ->
            return {}
        )()
    else
        # browser
        return window.$amd = ((window, document, html) ->
            $process = (() ->
            )()

            amd = window.$amd
            q = amd.q
            util = amd.util
            path = amd.path
            log = amd.log or console.log.bind(console)

            futures = {path: q.when(path)}

            amd.defineFactory = (moduleName) ->
                return (dependencies, factory) ->
                    return define(moduleName, dependencies, factory)

            amd.define = define = (moduleName, dependencies, factory) ->
                if not util.isFunction(factory)
                    factory = dependencies
                    dependencies = []

                if not util.isFunction(factory)
                    throw new Error("module factory should be a function")

                module = createModule(moduleName, dependencies, factory)

                if not future = futures[moduleName]
                    future = createFuture(moduleName)

                children = loadMany(dependencies, (name) -> module.load(name))
                children.then(module.init.bind(module)).then(future.resolve, future.reject)

                return future.promise

            amd.load = load = (module) ->
                if not future = futures[module]
                    future = createFuture(module)
                    script = document.createElement('script')
                    script.async = true
                    script.src = module
                    script.onerror = () ->
                        log("error loading #{module}")
                        future.reject(new Error())
                    html.appendChild(script)
                return future.promise

            amd.loadMany = loadMany = (modules, $load) ->
                if not $load then $load = load
                promises = []
                for module in modules
                    if util.isString(module)
                        promises.push($load(module))
                    else if util.isArray(module)
                        list = []
                        for $module in module
                            list.push($load($module))
                        promises.push(q.all.list(list))
                    else
                        hash = {}
                        for own key, $module of module
                            hash[key] = $load($module)
                        promises.push(q.all.hash(hash))
                return q.all.list(promises)

            createFuture = (moduleName) ->
                return futures[moduleName] = q.defer {
                    graceful: true, timeout: LOAD_TIMEOUT
                }

            createModule = (name, dependencies, factory) ->
                return new Module(name, dependencies, factory)

            amd.Module = class Module
                constructor: (name, dependencies, factory) ->
                    Object.defineProperties this, {
                        amd: {value: amd}
                        name: {value: name}
                        filename: {value: name}
                        dirname: {value: path.dirname(name)}
                        dependencies: {value: dependencies}
                        factory: {value: factory}
                        isBrowser: {value: true}
                        global: {value: window}
                        process: {value: $process}
                        window: {value: window}
                        document: {value: document}
                    }
                    return

                load: (name) -> return load(path.join(this.dirname, name))

                init: (dependencies) ->
                    Object.defineProperties this, {
                        children: {value: dependencies}
                    }
                    exports = this.factory.apply(this, dependencies)
                    return q.when(exports).then (exports) ->
                        Object.defineProperties this, {
                            exports: {value: exports}
                        }
                        return exports

            return amd
        )(window, document, document.documentElement or document)
)()
