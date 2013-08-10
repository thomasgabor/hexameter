local zmq = require "zmq"
local json = require "dkjson"
local serialize = require "serialize"

local string = string

local error = error
local type = type
local assert = assert
local loadstring = loadstring
--local print = print

module(...)

local recvtries  = 100000 --magic number achieved through tests
local defaultport = 55555
local defaultcode = "json"

local context, self, port, processor, resolver, coder, respondsocket


--  basic function library  --------------------------------------------------------------------------------------------

local function address(component)
	if type(component) == "string" then
		return component
	end
	if type(component) == "number" then
		return "localhost:"..component
	end
	error("Given argument "..serialize.presentation(component).." is not a address.")
end

local codes = {
    lua = {
        encode = serialize.data,
        decode = function (message)
            return loadstring(message)()
        end
    },
    json = json
}


--  external interface  ------------------------------------------------------------------------------------------------

function init(name, callback, codename, network)
    context = zmq.init(1)
    self = name or "localhost:"..defaultport
    port = string.match(self, "^[%w%p]*:") and string.gsub(self, "^[%w%p]*:", "") or defaultport
    processor = callback or function (type, parameter, author, space)
        if type == "ack" then
            return nil
		elseif type == "syn" then
			return parameter
        else
            return ("answer to "..serialize.data(parameter))
        end
    end
	resolver = network or address
    codename = codename or defaultcode
    coder = codes[codename]
    coder.name = codename
	respondsocket = context:socket(zmq.ROUTER)
	respondsocket:bind("tcp://*:"..port)
end

function term()
    respondsocket:close()
	context:term()
end

function message(type, recipient, space, parameter)
    local msg = coder.name.."\n\n"
    msg = msg..coder.encode({
		recipient=resolver(recipient),
		author=resolver(self),
		type=type,
		parameter=parameter,
		space=space
	})
    local socket = context:socket(zmq.REQ)
    --socket:setopt(zmq.LINGER, 0) --no idea why this doesn't work
	socket:connect("tcp://"..resolver(recipient))
	local success = socket:send(msg)
	socket:close()
    return success
end

function syn(recipient, space, parameter)
    return message("syn", recipient, space, parameter)
end

function ack(recipient, space, parameter)
    return message("ack", recipient, space, parameter)
end

function respond(tries)
    tries = tries or recvtries
	local src, del, msg --deliberately set to nil
	if tries == 0 then
	    src = respondsocket:recv()
		del = respondsocket:recv()
		msg = respondsocket:recv()
	end
	local i = 0
	local noblockrecv = false
	while (not msg) and (not noblockrecv) and i < tries do
		src = respondsocket:recv(zmq.NOBLOCK)
		if src then
		    noblockrecv = true
		end
		i = i + 1
	end
	if noblockrecv then
	    del = respondsocket:recv()
		msg = respondsocket:recv()
	end
	if msg then
		local codename = string.match(msg, "^(%w*)\n\n") or ""
		assert(codes[codename], "received message with invalid encoding \""..codename.."\"") --TODO: make more tolerant later?
		if msg then
			local mess = codes[codename].decode(string.gsub(msg, "^(%w*)\n\n", ""))
			local resp = processor(mess.type, mess.parameter, mess.author, mess.space, mess.recipient)
			if resp then
				return ack(mess.author, mess.space, resp)
			end
		end
	    return true
	else
		return false
	end
end

function me()
    return self
end