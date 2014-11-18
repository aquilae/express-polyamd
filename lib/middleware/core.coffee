((module, __dirname) ->
    path = require('path')
    modules = require('./modules')

    module.exports = (coreMountPoint) ->
        if not coreMountPoint?
            coreMountPoint = '/polyamd'

        return modules {
            rootPath: path.join(__dirname, '../core/')
            rootUrl: coreMountPoint
        }
)(module, __dirname)
