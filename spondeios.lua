require "serialize"

module(..., package.seeall)

local defaultspheres = {"flagging"}

local function equal(a, b)
    if type(a) == type(b) then
        if type(a) == "table" then
            for key,val in pairs(a) do
                if not equal(b[key], val) then
                    return false
                end
            end
            return true
        end
        return a == b
    end
    return false
end

function filter(item, pattern)
    local meta = {}
    local newitem = {}
    if type(item) == "table" then
        for key,val in pairs(item) do
            if type(key) == "string" and string.match(key, pattern) then
                meta[key] = val
            else
                newitem[key] = val
            end
        end
    end
    return newitem, meta
end

local spaces = {
    trivial = function ()
        return function(type, parameter, author, space)
            return ("answer to "..serialize.data(parameter).." from "..author.."@"..space.."\n")
        end
    end,
    memory = function ()
        local memory = {}
        return function (type, parameter, author, space)
            memory[space] = memory[space] or {}
            if type == "get" or type == "qry" then
                local response = {}
                for i,item in ipairs(parameter) do
                    for t,tuple in ipairs(memory[space]) do
                        if equal(item, tuple) then
                            if type == "get" then
                                table.remove(memory[space], t)
                            end
                            table.insert(response, tuple)
                        end
                    end
                end
                return response
            end
            if type == "put" then
                for i,item in ipairs(parameter) do
                    for t,tuple in ipairs(memory[space]) do
                        if equal(tuple, parameter) then
                            table.remove(memory[space], t)
                        end
                    end
                    table.insert(memory[space], item)
                end
                return parameter
            end
        end
    end
}


local spheres = {
    id = function (continuation)
        return function (...)
            return continuation(...)
        end
    end,
    verbose = function (continuation)
        return function (type, parameter, author, space)
            print("--  [received "..type.."]  ", serialize.data(parameter))
            print("--                  @", space, " from ", author)
            return continuation(type, parameter, author, space)
        end
    end,
    flagging = function (continuation)
        return function (msgtype, parameter, author, space)
            local response = {}
            local requested = false
            local answered = false
            for i,item in ipairs(parameter) do
                requested = true
                local newitem, flags = filter(item, "^#")
                local answers = continuation(msgtype, {newitem}, author, space)
                if answers then
                    answered = true
                    for a,answer in ipairs(answers) do
                        local newanswer = {}
                        for key,val in pairs(answer) do
                            newanswer[key] = val
                        end
                        for key,val in pairs(flags) do
                            newanswer[key] = val
                        end
                        table.insert(response, newanswer)
                    end
                end
            end
            if requested then
                if answered then
                    return response
                else
                    return nil
                end
            else
                return continuation(msgtype, parameter, author, space)
            end
        end
    end
}


process = function () error("spondeios processing not initialized!") end


function init(character, wrappers)
    process = (spaces[character] or (type(character) == "function" and character) or spaces.memory)()
    wrappers = wrappers or defaultspheres
    for i,wrapper in ipairs(wrappers) do
        process = (spheres[wrapper] or (type(wrapper) == "function" and wrapper) or spheres.id)(process)
    end
end