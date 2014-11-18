((module) ->
    $path = require('./core/path')
    util = require('./core/util')
    delay = require('./core/delay')
    timeout = require('./core/timeout')
    q = require('./core/q')
    amd = require('./core/amd')

    middleware = {
        core: require('./middleware/core')
        assets: require('./middleware/assets')
    }

    amd.util = util
    amd.util.delay = delay
    amd.util.timeout = timeout
    amd.q = q

    amd.serveCore = middleware.core
    amd.serveAssets = middleware.assets

    amd.includeScripts = (coreMountPoint) ->
        if not coreMountPoint?
            coreMountPoint = '/polyamd'
        scripts = ['util', 'delay', 'timeout', 'path', 'q', 'amd']
        scripts = scripts.map (script) ->
            return $path.join(coreMountPoint, script)
        scripts = scripts.map (script) ->
            return "<script src=\"#{script}\" type=\"text/javascript\"></script>"
        return scripts.join('\n')

    return module.exports = amd
)(module)
