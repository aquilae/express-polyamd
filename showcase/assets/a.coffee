console.log("loading a")
define ['./c'], (c) ->
    console.log("a loaded:", c)
    return {
        me: 'a'
        deps: [c]
    }
