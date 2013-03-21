require "hexameter"
require "serialize"

local me

local world = {
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
                run = function () return 42 end
            },
            {
                type = "moveup",
                run = function (me)
                    me.state.x = me.state.x + 1
                    return me
                end
            }
        },
        state = {
            x = 5,
            y = 5
        },
        ticked = false
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
                        table.insert(response, {body=item.body, type=sensor.type, value=sensor.measure(world[item.body], world)})
                    end
                end
            end
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
        if msgtype == "put" and string.match(space, "^ticks") then
            for i,item in ipairs(parameter) do
                world[item.body].ticked = true
            end
        end
    end
end

if arg[1] then
    me = arg[1]
else
    io.write("Enter an address:port for this component: ")
    me = io.read("*line")
end

hexameter.init(me, time)
io.write("Hades running. Please exit with Ctrl+C.\n")


while true do
    hexameter.respond()
    local allticked = true
    for t,thing in pairs(world) do
        allticked = allticked and thing.ticked
    end
    if allticked then
        clock = clock + 1
        io.write("Starting discrete time period #"..clock.."...\n")
        for a,action in ipairs(next) do
            action()
        end
        for t,thing in pairs(world) do
            thing.ticked = false
            io.write("  state of "..t.."\n")
            io.write("     "..serialize.data(thing.state).."\n")
        end
    end
end