console.log("loading b")
define ['./c'], (c) ->
    console.log("b loaded:", c)
    return {
        me: 'b'
        deps: [c]
    }
