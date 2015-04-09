local rr = {}

function rr.encode(val)
	local s = ""
	if type(val) == "number" then
		s = "number:" .. tostring(val)
	elseif type(val) == "string" then
		s = "string:" .. val
	elseif type(val) == "table" then
		local d = serpent.dump(val)
		s = "table:" .. d
	elseif type(val) == "function" then
		local f = string.dump(val)
		s = "function:" .. f
	end

	return #s .. ":" .. s
end

function rr.decode(val)
	local t, r = string.match(val, "(%a+):(.*)")

	if t == "number" then
		return tonumber(r)
	elseif t == "string" then
		return tostring(r)
	elseif t == "table" then
		return loadstring(r)()
	elseif t == "function" then
		return loadstring(r)
	end
end

function rr.sendParameter(client, p)
	local s = rr.encode(p)
	client:send(s .. "\n")
end

function rr.receiveParameter(client)
	local size = ""

	repeat
		size = size .. client:receive(1)
	until size:sub(-1) == ":"

	size = tonumber(size:sub(1, -2))

	local data = client:receive(size)
	return rr.decode(data)
end

function rr.loadfile(client, file)
	client:send("loadfile=" .. file .. "\n")
	local sizeTxt = client:receive("*l")
	local size = tonumber(string.match(sizeTxt, ".+=(.+)"))
	local data = client:receive(size)

	return loadstring(data, "=" .. file)
end

function rr.sendfile(node, file)
	local fh, msg = io.open(file, "r")

	if not fh then
		print("Could not open file '" .. tostring(file) .. "'")
		print("Reason: " .. tostring(msg))
		os.exit()
	end

	local f = fh:read("*a")
	fh:close()

	node:send("size=" .. #f .. "\n")
	node:send(f)
end

function rr.executeremote(client, f, ...)
	local p = {...}
	assert(type(f) == "string", "Function name is not a string")
	client:send("call=" .. f .. "\n")
	client:send("parameters=" .. #p .. "\n")

	for i, v in ipairs(p) do
		rr.sendParameter(client, v)
	end

	local lineReturns = client:receive("*l")
	local nReturns = tonumber(string.match(lineReturns, ".-=(.+)"))

	local returns = {}

	for i = 1, nReturns do
		local p = rr.receiveParameter(client)
		returns[#returns + 1] = p
	end

	return unpack(returns)
end

return rr