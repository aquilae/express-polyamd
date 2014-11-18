((module) ->
    fs = require('fs')
    path = require('path')
    cs = require('coffee-script')
    $path = require('../core/path')

    regexps = {
        mod: /^\/(.+)$/
        map: /^\/(.+)\.map$/
        cs: /^\/(.+)\.coffee$/
        js: /^\/(.+)\.js$/
    }

    tests = {
        mod: (url) -> return (match = regexps.mod.exec(url)) and [match[1], 'mod']
        map: (url) -> return (match = regexps.map.exec(url)) and [match[1], 'map']
        cs: (url) -> return (match = regexps.cs.exec(url)) and [match[1], 'src']
        js: (url) -> return (match = regexps.js.exec(url)) and [match[1], 'src']
    }

    module.exports = (options) ->
        rootPath = options.rootPath
        rootUrl = options.rootUrl
        preprocess = options.preprocess

        getInfo = (name, callback) ->
            filename = path.join(rootPath, "#{name}.coffee")
            console.log('filename:', filename)
            fs.stat filename, (err, stats) ->
                console.log('stats:', err, stats)
                if err? or not stats.isFile()
                    filename = path.join(rootPath, "#{name}.js")
                    fs.stat filename, (err, stats) ->
                        if err? or not stats.isFile()
                            callback(null, null)
                        else
                            mod = $path.join(rootUrl, name)
                            map = mod + '.map'
                            src = mod + '.js'
                            type = 'js'
                            callback(null, {filename, mod, map, src, type})
                else
                    mod = $path.join(rootUrl, name)
                    map = mod + '.map'
                    src = mod + '.coffee'
                    type = 'cs'
                    callback(null, {filename, mod, map, src, type})

        serveMod = (info, res, next) ->
            fs.readFile info.filename, {encoding: 'utf8'}, (err, source) ->
                if err? then return next(err)
                try
                    if preprocess then source = preprocess(info, source)
                    switch info.type
                        when 'js'
                            bytes = new Buffer(source, 'utf8')
                        when 'cs'
                            opts = {filename: info.filename, sourceMap: true}
                            result = cs.compile(source, opts)
                            bytes = new Buffer(result.js, 'utf8')
                        else
                            return next(new Error("unknown module type: #{info.type}"))
                    res.set('Content-Type', 'text/javascript')
                    res.set('Content-Length', bytes.length)
                    res.set('X-SourceMap', info.map)
                catch exc
                    return next(exc)
                res.send(bytes)

        serveMap = (info, res, next) ->
            fs.readFile info.filename, {encoding: 'utf8'}, (err, source) ->
                if err? then return next(err)
                try
                    if preprocess then source = preprocess(info, source)
                    switch info.type
                        when 'js'
                            map = JSON.stringify {
                                version: 3
                                sourceRoot: ""
                                sources: [info.src]
                                file: info.mod
                                names: []
                                mappings: ""
                            }
                        when 'cs'
                            opts = {filename: info.filename, sourceMap: true}
                            result = cs.compile(source, opts)
                            map = result.sourceMap.generate {
                                sourceFiles: [info.src]
                                generatedFile: info.mod
                            }
                        else
                            return next(new Error("unknown module type: #{info.type}"))
                    bytes = new Buffer(map, 'utf8')
                    res.set('Content-Type', 'text/javascript')
                    res.set('Content-Length', bytes.length)
                catch exc
                    return next(exc)
                res.send(bytes)

        serveSrc = (info, res, next) ->
            fs.readFile info.filename, {encoding: 'utf8'}, (err, source) ->
                if err? then return next(err)
                try
                    if preprocess then source = preprocess(info, source)
                    switch info.type
                        when 'js' then res.set('Content-Type', 'text/javascript')
                        when 'cs' then res.set('Content-Type', 'text/coffeescript')
                        else return next(new Error("unknown module type: #{info.type}"))
                    bytes = new Buffer(source, 'utf8')
                    res.set('Content-Length', bytes.length)
                catch exc
                    return next(exc)
                res.send(bytes)

        return (req, res, next) ->
            [name, type] = tests.js(req.url) or
                           tests.cs(req.url) or
                           tests.map(req.url) or
                           tests.mod(req.url) or
                           null

            if name == null then return next()
            console.log('name:', name)
            getInfo name, (err, info) ->
                console.log('info:', err, info)
                if err? then return next(err)
                if info == null then return next()

                switch type
                    when 'mod' then serveMod(info, res, next)
                    when 'map' then serveMap(info, res, next)
                    when 'src' then serveSrc(info, res, next)
                    else return next()
)(module)
