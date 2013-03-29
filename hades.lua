require "hexameter"
require "serialize"

local me

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
            y = 5
        },
        tick = false,
        tocked = false
    }
}

local clock = 0

local next = {}

local time = function ()
    return function(msgtype, parameter, author, space)
        local response = {}
        if (msgtype == "qry" or msgtype == "get") and string.match(space, "^sensors") then
            for i,item in ipairs(parameter) do
                for s,sensor in pairs(world[item.body].sensors) do
                    if item.type and sensor.type == item.type then
                        --TODO: check for tock, wait for untock?
                        table.insert(response, {body=item.body, type=sensor.type, value=sensor.measure(world[item.body], world)})
                    end
                end
            end
            return response
        end
        if msgtype == "put" and string.match(space, "^motors") then
            for i,item in ipairs(parameter) do
                for m,motor in pairs(world[item.body].motors) do
                    if item.type and motor.type == item.type then
                        table.insert(next, function () world[item.body] = motor.run(world[item.body], world) end)
                    end
                end
            end
        end
        if msgtype == "put" and string.match(space, "^tocks") then
            for i,item in ipairs(parameter) do
                world[item.body].tocked = true
            end
        end
        return nil --making this explicit here
    end
end

if arg[1] then
    me = arg[1]
else
    io.write("Enter an address:port for this component: ")
    me = io.read("*line")
end

if arg[2] then
    io.write("Loading "..arg[2].."...")
    dofile(arg[2])
    io.write("\n")
else
    io.write("Using default \"magic brick world\".\n")
end

hexameter.init(me, time)
io.write("Hades running. Please exit with Ctrl+C.\n")


while true do
    hexameter.respond(0)
    local alltocked = true
    for t,thing in pairs(world) do
        alltocked = alltocked and thing.tocked
    end
    if alltocked then
        clock = clock + 1
        io.write("Starting discrete time period #"..clock.."...\n")
        for a,action in ipairs(next) do
            action()
        end
        for t,thing in pairs(world) do
            thing.tocked = false
            io.write("  state of "..t.."\n")
            io.write("     "..serialize.data(thing.state).."\n")
        end
        next = {}
    end
end