world = {
    brick = {
        sensors = {
            {
                type = "meaning of life the universe and everything",
                measure = function (me, world) return 42 end
            }
        },
        motors = {
            {
                type = "procrastinate",
                run = function (me)
                    return me
                end
            },
            {
                type = "moveup",
                run = function (me)
                    me.state.y = me.state.y + 1
                    return me
                end
            }
        },
        state = {
            x = 5,
            y = 5,
            performed = {}
        },
        tick = {},
        tocked = false
    }
}

return world