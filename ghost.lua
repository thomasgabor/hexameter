--GHOST hands-on scel terminal
package.path = (string.match(arg[0], "^.*/") or "./").."?.lua;"..package.path
require "hexameter"
require "serialize"
local show = serialize.presentation

local commands
local me, target, environment
local hiddenvars = {}

focus = ""

local function interpret(parameter)
    return loadstring("return "..parameter)()
end

function multiarg(argument)
    if not (type(argument) == "string") then
        return argument
    end
    local parapattern = "^%s*([%w%.]+)%s+(.*)$"
    local args = {}
    argument = argument.." "
    while string.match(argument, parapattern) do
        table.insert(args, (string.gsub(argument, parapattern, "%1")))
        argument = string.gsub(argument, parapattern, "%2")
    end
    if not string.match(argument, "^%s*$") then
        table.insert(args, interpret(argument))
    end
    return unpack(args)
end

function dualarg(argument)
    return string.match(argument, "%s*(%S+)%s+(%S+)%s*$")
end

function extract(argument)
    local parameter,space = string.match(argument, "^%s*(.+)%s*@%s*(.+)%s*$")
    return interpret(parameter), space
end

function fullextract(argument)
    local type, parameter, space = string.match(argument, "^%s*(.-)%s+(.-)%s*@%s*(%S+)%s*$")
    return type, interpret(parameter), space
end

local function primitive(type)
    return function(argument)
        local parameter, space = extract(argument)
        hexameter.tell(type, target, space, {parameter})
    end
end

local function execute(input)
    local command = string.match(input, "^(%w+)%s*")
    local argument = string.gsub(input, "^(%w+)%s*", "")
    local call = commands[environment][command] or commands["standard"][command] or commands["user"][command]
    if type(call) == "function" then
        call(argument, me, target, environment, focus, hiddenvars)
    else
        io.write("##  unrecognized command \"", command or "<none>", "\"\n")
    end
end

local function trim(str)
    str = string.gsub(str, "^%s+", "")
    str = string.gsub(str, "%s+$", "")
    return str
end

local function run(lines)
    local buffer = ""
    local top = true
    for line in lines do
        if not string.match(line, "^%s*$") then
            if not string.match(line, "^%s*#") then
                if string.match(line, "^%s*//") then
                    top = false
                elseif string.match(line, "%s*\\\\") then
                    execute(buffer)
                    buffer = ""
                    top = true
                else
                    if top then
                        execute(line)
                    else
                        buffer = buffer..line.."\n"
                    end
                end
            end
        end
    end
end

local function runfile(file)
    return run(io.lines(file))
end

local function runlines(lines)
    return run(pairs(lines))
end

commands = {
    standard = {
        lua = function (argument)
            print("%%  ", loadstring("return "..argument)())
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
        tell = function(argument)
            local type, parameter, space = fullextract(argument)
            if not type then print("##  Missing or incorrect first argument to tell: type") end
            if not parameter then print("##  Missing or incorrect second argument to tell: parameter") end
            if not space then print("##  Missing or incorrect third argument to tell: space, preceded by an @ sign") end
            hexameter.tell(type, target, space, {parameter})
        end,
        ask = function(argument)
            local type, parameter, space = fullextract(argument)
            if not type then print("##  Missing or incorrect first argument to ask: type") end
            if not parameter then print("##  Missing or incorrect second argument to ask: parameter") end
            if not space then print("##  Missing or incorrect third argument to ask: space, preceded by an @ sign") end
            local response = hexameter.ask(type, target, space, {parameter})
            print("**  Received response: ", serialize.literal(response))
        end,
        wonder = function(argument)
            local type, parameter, space = fullextract(argument)
            if not type then print("##  Missing or incorrect first argument to wonder: type") end
            if not parameter then print("##  Missing or incorrect second argument to wonder: parameter") end
            if not space then print("##  Missing or incorrect third argument to wonder: space, preceded by an @ sign") end
            local response = hexameter.wonder(type, target, space, {parameter})
            if response then
                print("**  Received response: ", serialize.literal(response))
            else
                print("**  No response received.")
            end
        end,
        meet = function (argument)
            --argument = string.gsub(argument, "%s", "")
            commands.standard.target(argument)
            hexameter.meet(target)
        end,
        friends = function ()
            print("==  ", serialize.literal(hexameter.friends()))
        end,
        checkex = function (argument)
            local parameter, space = extract(argument)
            local result = hexameter.ask("qry", me, space, {parameter})
            print("^^  ", serialize.data(result))
        end,
        check = function (argument)
            local parameter, space = extract(argument)
            local result = hexameter.process("qry", target, space, {parameter})
            print("^^  ", serialize.data(result))
        end,
        enter = function (argument)
            local env, focus = multiarg(argument)
            env = trim(env)
            focus = trim(focus)
            if commands[env] then
                if commands[environment].exit then
                    commands[environment].exit()
                end
                environment = env
                if commands[environment].init then
                    commands[environment].init(focus)
                end
            else
                io.write("##  command environment \"", env, "\" does not exist.\n")
            end
        end,
        help = function ()
            io.write("~~  available commands: help")
            for name,command in pairs(commands.standard) do
                if not (name == "help") then
                    io.write(", "..name)
                end
            end
            io.write("\n")
        end,
        declare = function (argument)
            io.write("**  declaring command environment ", argument, "\n")
            commands[trim(argument)] = {}
        end,
        define = function (argument)
            local name, body = multiarg(argument)
            if string.match(name, "^(.+)%.(.+)$") then
                local package, localname = string.match(name, "^(.+)%.(.+)$")
                commands[package][localname] = body
            else
                commands.user[name] = body
            end
        end,
        alt = function (argument) --TODO: augment this with error messages in cases in which it doesn't work as expected!
            local original,new = dualarg(argument)
            commands.user[new] = commands.user[original]
        end,
        include = function(argument)
            print("::  Loading "..argument.."...")
            run(argument)
        end
    },
    user = {}
}

commands.standard.l = commands.standard.lua
commands.standard.t = commands.standard.target
commands.standard.q = commands.standard.quit
commands.standard.m = commands.standard.meet
commands.standard.e = commands.standard.enter
commands.standard.re = commands.standard.respond
commands.standard.ch = commands.standard.check
commands.standard.fs = commands.standard.friends
commands.standard.ch = commands.standard.check
commands.standard.def = commands.standard.define
commands.standard.inc = commands.standard.include

if arg[1] then
    me = arg[1]
else
    io.write("??  Enter an address:port for this component: ")
    me = io.read("*line")
end

hexameter.init(me, nil, {"networking", "forwarding", "flagging", "verbose"})
target = me
environment = "standard"
focus = ""

local scripting = false
local prescript = ""
for i,argument in ipairs(arg) do
    if not (i == 1) then
        if argument == "--" then
            scripting = true
        else
            if scripting then
                prescript = prescript.." "..argument
            else
                runfile(argument)
            end
        end
    end
end
if scripting then
    for match in string.gmatch(prescript..",", "([^,]*)[,\n]") do
        execute(trim(match))
    end
end

while true do
    io.write("[", me, "] for [", target, "]> ")
    if not (environment == "standard") then
        if not (focus == "") then
            io.write("{", focus, "|", environment, "} ")
        else
            io.write("{", environment, "} ")
        end
    end
    local input = io.read("*line")
    execute(input)
end