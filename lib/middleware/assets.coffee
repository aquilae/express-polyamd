((module) ->
    modules = require('./modules')

    module.exports = (assetsRootPath, assetsMountPoint) ->
        return modules {
            rootPath: assetsRootPath
            rootUrl: assetsMountPoint
            preprocess: (info, source) ->
                switch info.type
                    when 'js'
                        return "(function(){var define=$amd.defineFactory('#{info.mod}');\t\t\t\t#{source}\t\t\t\t;})()"
                    when 'cs'
                        return "define=$amd.defineFactory('#{info.mod}');\t\t\t\t#{source}"
                    else
                        throw new Error("unknown module type: #{info.type}")
        }
)(module)
