((factory) ->
    if typeof (window) == 'undefined'
        module.exports = factory()
    else
        window.$amd.path = factory()
)(() ->
    isAbsolute = (path) -> return path.charAt(0) == '/'

    splitPathRe = /^(\/?|)([\s\S]*?)((?:\.{1,2}|[^\/]+?|)(\.[^.\/]*|))(?:[\/]*)$/
    splitPath = (filename) -> return splitPathRe.exec(filename).slice(1);

    normalizeArray = (parts, allowAboveRoot) ->
        up = 0
        for i in [parts.length-1..0]
            ((index) ->
                last = parts[index]
                if last == '.'
                    parts.splice(index, 1)
                else if last == '..'
                    parts.splice(index, 1)
                    ++up
                else if up
                    parts.splice(index, 1)
                    --up
            )(i)
        if allowAboveRoot
            while --up
                parts.unshift('..')
        return parts

    normalize = (path) ->
        path = path.replace(/\\/g, '/')
        absolute = isAbsolute(path)
        trailing = path[-1...] == '/'
        segments = path.split('/')
        segments = segments.filter((obj) -> obj)

        path = normalizeArray(segments, not absolute).join('/')

        if not path and not absolute then path = ''
        if path and trailing then path += '/'

        return (if absolute then '/' else '') + path

    dirname = (path) ->
        path = path.replace(/\\/g, '/')
        result = splitPath(path)
        [root, dir] = result
        if not root and not dir then return '.'
        return root + (if dir then dir[0...-1] else dir)

    join = (segments...) ->
        path = ''
        for segment in segments
            if typeof (segment) != 'string'
                throw new TypeError('Arguments to path.join must be strings')
            if segment
                segment = segment.replace(/\\/g, '/')
                path += (if path then '/' else '') + segment
        return normalize(path)

    return {
        isAbsolute
        normalize
        dirname
        join
    }
)
