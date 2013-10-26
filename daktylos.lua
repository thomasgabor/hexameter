local zmq = require "zmq"
local json = require "dkjson"
local serialize = require "serialize"

local string = string
local table = table

local error = error
local type = type
local assert = assert
local loadstring = loadstring
local unpack = unpack
local ipairs = ipairs
local pairs = pairs
local print = print

module(...)

local recvtries  = 100000 --magic number achieved through tests
local defaultport = 55555
local defaultcode = "json"
local socketcache = 0

local context, self, port, processor, resolver, coder, respondsocket, talksockets


--  basic function library  --------------------------------------------------------------------------------------------

local codes = {
    lua = {
        encode = serialize.data,
        decode = function (message)
            return loadstring(message)()
        end
    },
    json = json
}

local function address(component)  --default address resolution
	if type(component) == "string" then
		return component
	end
	if type(component) == "number" then
		return "localhost:"..component
	end
	error("Given argument "..serialize.presentation(component).." is not a address.")
end


--  protocol functionality ---------------------------------------------------------------------------------------------

local function getsocket(target)
    if socketcache > 0 then
		for _,talksocketdata in ipairs(talksockets) do
			if talksocketdata.target == target then
				return talksocketdata.socket
			end
		end
		if #talksockets == socketcache then
			talksockets[1].socket:close()
			table.remove(talksockets, 1)
		end
	end
	local socket = context:socket(zmq.DEALER)
    --socket:setopt(zmq.LINGER, 0) --no idea why the zmq binding doesn't recognize this option
	socket:connect(target)
	if socketcache > 0 then
		table.insert(talksockets, {socket=socket, target=target})
	end
	return socket
end

local function multisend(socket, ...)  --send a message consisting of mutliple frames
	for i,frame in ipairs(arg) do
		if i == #arg then
			return socket:send(frame)
		else
			socket:send(frame, zmq.SNDMORE)
		end
	end
end

local function multirecv(socket, recvoptions)  --receive all frames of a message
	local frames = {}
	frames[#frames+1] = socket:recv(recvoptions)
	while socket:getopt(zmq.RCVMORE) == 1 do
		frames[#frames+1] = socket:recv()
	end
	return unpack(frames)
end


--  hexameter interface  -----------------------------------------------------------------------------------------------

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
	talksockets = {}
end

function term()
    respondsocket:close()
	context:term()
end

function me()
    return self
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
	--print("%%")
	--print(msg)
	--print("%%")
    local socket = getsocket("tcp://"..resolver(recipient))
	return multisend(socket, "", msg)
end

function respond(tries)
    tries = tries or recvtries
	local src, del, msg --deliberately set to nil
	if tries == 0 then
		src, del, msg = multirecv(respondsocket)
	end
	local i = 0
	while (not msg) and i < tries do
		src, del, msg = multirecv(respondsocket, zmq.NOBLOCK)
		i = i + 1
	end
	if msg then
		--print("%%")
		--print(msg)
		--print("%%")
		local codename = string.match(msg, "^(%w*)\n\n") or ""
		assert(codes[codename], "received message with invalid encoding \""..codename.."\"")
		if msg then
			local mess = codes[codename].decode(string.gsub(msg, "^(%w*)\n\n", ""))
			local resp = processor(mess.type, mess.author, mess.space, mess.parameter, mess.recipient)
			if resp then
				return ack(mess.author, mess.space, resp)
			end
		end
	    return true
	else
		return false
	end
end


--  additional interface -----------------------------------------------------------------------------------------------

function syn(recipient, space, parameter)
    return message("syn", recipient, space, parameter)
end

function ack(recipient, space, parameter)
    return message("ack", recipient, space, parameter)
end