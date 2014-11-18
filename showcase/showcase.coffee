fs = require('fs')
path = require('path')
express = require('express')
coffee = require('coffee-script')
polyamd = require('../lib/index')

app = express()

sendFile = (filename, mimetype, res, next) ->
    console.log("sendFile() #{filename}")
    fs.readFile path.join(__dirname, filename), (err, bytes) ->
        if err? then return next()
        res.set('Content-Type', mimetype)
        res.set('Content-Length', bytes.length)
        res.send(bytes)

sendCoffee = (filename, res, next) ->
    sendFile(filename, 'text/coffeescript', res, next)

sendHtml = (filename, res, next) ->
    fs.readFile path.join(__dirname, filename), {encoding: 'utf8'}, (err, string) ->
        if err? then return next(err)
        string = string.replace('#{includeScripts()}', app.locals.includeScripts())
        bytes = new Buffer(string, 'utf8')
        res.set('Content-Type', 'text/html')
        res.set('Content-Length', bytes.length)
        res.send(bytes)

###
serveCoffee = (url, src, file) ->
    map = url + '.map'
    this.use url, (req, res, next) ->
        fs.readFile path.join(__dirname, file), {encoding: 'utf8'}, (err, source) ->
            if err? then return next(err)
            result = coffee.compile(source, {filename: file, sourceMap: true})
            bytes = new Buffer(result.js, 'utf8')
            res.set('Content-Type', 'text/javascript')
            res.set('Content-Length', bytes.length)
            res.set('X-SourceMap', map)
            res.send(bytes)
    this.use map, (req, res, next) ->
        fs.readFile path.join(__dirname, file), {encoding: 'utf8'}, (err, source) ->
            if err? then return next(err)
            result = coffee.compile(source, {filename: file, sourceMap: true})
            bytes = new Buffer(result.sourceMap.generate({sourceFiles: [src], generatedFile: url}), 'utf8')
            res.set('Content-Type', 'text/javascript')
            res.set('Content-Length', bytes.length)
            res.send(bytes)
    this.use src, (req, res, next) -> sendCoffee(file, res, next)

app.use (req, res, next) ->
    console.log("#{req.method} #{req.url}")
    next()

serveCoffee.call(app, '/util.js', '/util.coffee', '../lib/core/util.coffee')
serveCoffee.call(app, '/delay.js', '/delay.coffee', '../lib/core/delay.coffee')
serveCoffee.call(app, '/timeout.js', '/timeout.coffee', '../lib/core/timeout.coffee')
serveCoffee.call(app, '/q.js', '/q.coffee', '../lib/core/q.coffee')
serveCoffee.call(app, '/amd.js', '/amd.coffee', '../lib/core/amd.coffee')
serveCoffee.call(app, '/a', '/a.coffee', './a.coffee')
serveCoffee.call(app, '/b', '/b.coffee', './b.coffee')
serveCoffee.call(app, '/c', '/c.coffee', './c.coffee')

###

app.locals.includeScripts = () -> return polyamd.includeScripts('/amd')

app.use('/amd/', polyamd.serveCore('/amd'))
app.use('/assets/', polyamd.serveAssets(path.join(__dirname, './assets'), '/assets'))

app.use (req, res, next) ->
    sendHtml('./showcase.html', res, next)

app.use (err, req, res, next) ->
    console.error(err.stack)
    bytes = new Buffer(err.stack, 'utf8')
    res.set('Content-Type', 'text/plain')
    res.set('Content-Length', bytes.length)
    res.send(bytes)

app.listen 7000, () ->
    console.log("Showcase server listening on port 7000")
