--HADES a discrete environment simulator

require "hexameter"
require "serialize"
local show = serialize.presentation


local me

local auto = {} --unique value

world = nil

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
                        table.insert(
                            response,
                            {
                                body=item.body,
                                type=sensor.type,
                                value=sensor.measure(world[item.body], world, item.control or {})
                            }
                        )
                    end
                end
            end
            return response
        end
        if msgtype == "put" and string.match(space, "^motors") then
            for i,item in ipairs(parameter) do
                for m,motor in pairs(world[item.body].motors) do
                    if item.type and motor.type == item.type then
                        --world[item.body].next = world[item.body].next or {}--needed later
                        table.insert(
                            next,
                            function ()
                                world[item.body] = motor.run(world[item.body], world, item.control or {})
                            end
                        )
                    end
                end
            end
        end
        if msgtype == "put" and string.match(space, "^ticks") then
            for i,item in ipairs(parameter) do
                world[item.body].tick = world[item.body].tick or {}
                world[item.body].tick[item.soul] = item.space or "hades.ticks"
            end
        end
        if msgtype == "put" and string.match(space, "^tocks") then --maybe implement command to set to auto
            for i,item in ipairs(parameter) do
                --TODO: check for non-existing item/body in world
                world[item.body].tocked = true
            end
        end
        return nil --making this explicit here
    end
end

if arg[1] then
    me = arg[1]
else
    io.write("??  Enter an address:port for this component: ")
    me = io.read("*line")
end

if arg[2] then
    io.write("::  Loading "..arg[2].."...")
    world = dofile(arg[2])
    io.write("\n")
else
    world = dofile("./scenarios/magicbrick/world.lua")
    io.write("::  Using default \"magic brick world\".\n")
end

if not (type(world) == "table") then
    io.write("##  World does not exist. Aborting.\n")
end

for t,thing in pairs(world) do
    thing.sensors = thing.sensors or {}
    thing.motors = thing.motors or {}
    thing.state = thing.state or {}
    thing.tick = thing.tick or {}
    thing.tocked = thing.tocked or false
end

hexameter.init(me, time)
io.write("::  Hades running. Please exit with Ctrl+C.\n")


while true do
    hexameter.respond(0)
    --print("**  current friends:", serialize.literal(hexameter.friends())) --command-line option to turn this on?
    local alltocked = true
    for t,thing in pairs(world) do
        if not (thing.tocked == auto) then
          alltocked = alltocked and thing.tocked
          print("**  [tock status] ", t, thing.tocked and " tocked" or " not tocked")
        end
    end
    if alltocked then
        clock = clock + 1
        io.write("\n\n\n..  Starting discrete time period #"..clock.."...\n")
        io.write("..  .......................................\n")
        for a,action in ipairs(next) do
            action()
        end
        for t,thing in pairs(world) do
            if not (thing.tocked == auto) then
                thing.tocked = false
            end
            io.write("    state of "..t.."\n")
            io.write("       "..serialize.presentation(thing.state).."\n")
        end
        io.write("..  .......................................\n\n")
        next = {}
        for t,thing in pairs(world) do
            for address,space in pairs(thing.tick) do
                if space then
                    hexameter.put(address, space, {{period = clock}})
                end
            end
        end
    end
end