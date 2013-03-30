require "hexameter"
require "serialize"

local me, target

local function extract(argument)
    local parameter,space = string.match(argument, "^%s*(.+)%s*@%s*(.+)%s*$")
    return loadstring("return "..parameter)(), space
end

local function primitive(type)
    return function(argument)
        local parameter, space = extract(argument)
        hexameter.tell(type, target, space, {parameter})
    end
end

if arg[1] then
    me = arg[1]
else
    io.write("Enter an address:port for this component: ")
    me = io.read("*line")
end

hexameter.init(me)
target = me

local commands --needed for the reference from inside the table's functions
commands = {
    lua = function (argument)
        loadstring(argument)()
    end,
    target = function (argument)
        if string.match(argument, "^%s*$") then
            target = me
        elseif string.match(argument, "^%d+$") then
            target = "localhost:"..argument
        else    
            target = argument
        end
    end,
    qry = primitive("qry"),
    get = primitive("get"),
    put = primitive("put"),
    respond = function ()
        hexameter.respond()
    end,
    quit = function ()
        --hexameter.term()
        os.exit()
    end,
    meet = function (argument)
        commands.target(argument)
        hexameter.meet(target)
    end,
    friends = function ()
        print("==  ", serialize.data(hexameter.friends()))
    end,
    checkex = function (argument)
        local parameter, space = extract(argument)
        local result = hexameter.ask("qry", me, space, {parameter})
        print("++  ", serialize.data(result))
    end,
    check = function (argument)
        local parameter, space = extract(argument)
        local result = hexameter.process("qry", target, space, {parameter})
        print("++  ", serialize.data(result))
    end,
    help = function ()
        io.write("~~  available commands: help")
        for name,command in pairs(commands) do
            if not (name == "help") then
                io.write(", "..name)
            end
        end
        io.write("\n")
    end
}

commands.l = commands.lua
commands.t = commands.target
commands.q = commands.quit
commands.m = commands.meet
commands.re = commands.respond
commands.ch = commands.check
commands.fs = commands.friends
commands.ch = commands.check

while true do
    io.write("[", me, "] for [", target, "]> ")
    local input = io.read("*line")
    local command = string.match(input, "^(%w+)%s*")
    local argument = string.gsub(input, "^(%w+)%s*", "")
    if commands[command] then
        commands[command](argument)
    else
        io.write("##  unrecognized command \"", command or "<none>", "\"\n")
    end
end