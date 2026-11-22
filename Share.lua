-- Share: guides as text. Export gives "CB1:" plus base64 of a small serializer; import parses that
-- as data only (never loadstring) and keeps only known guide fields with sane types and sizes.
local _, ns = ...

local Share = {}
ns.Share = Share

local PREFIX = "CB1:"
local MAX_STEPS, MAX_MATS, MAX_STR, MAX_DEPTH = 300, 60, 120, 8

-- Serializer --------------------------------------------------------------------------------
-- t{ key value ... }  s<len>:<bytes>  n<number>;  T  F    (keys and values the same grammar)

local function ser(v, out, depth)
	local tv = type(v)
	if tv == "string" then
		out[#out + 1] = "s" .. #v .. ":" .. v
	elseif tv == "number" then
		out[#out + 1] = "n" .. (v == math.floor(v) and ("%d"):format(v) or ("%.4f"):format(v)) .. ";"
	elseif tv == "boolean" then
		out[#out + 1] = v and "T" or "F"
	elseif tv == "table" then
		if depth > MAX_DEPTH then error("too deep", 0) end
		out[#out + 1] = "t"
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for _, k in ipairs(keys) do
			ser(k, out, depth + 1)
			ser(v[k], out, depth + 1)
		end
		out[#out + 1] = "e"
	end
end

function Share.Serialize(v)
	local out = {}
	ser(v, out, 0)
	return table.concat(out)
end

-- returns value, next position; errors on bad input
local function des(s, i, depth)
	local c = s:sub(i, i)
	if c == "s" then
		local len, colon = s:match("^(%d+)():", i + 1)
		len = tonumber(len)
		if not len or len > 4096 then error("bad string", 0) end
		local str = s:sub(colon + 1, colon + len)
		if #str ~= len then error("short string", 0) end
		return str, colon + len + 1
	elseif c == "n" then
		local num, after = s:match("^(%-?%d+%.?%d*);()", i + 1)
		if not num then error("bad number", 0) end
		return tonumber(num), after
	elseif c == "T" then return true, i + 1
	elseif c == "F" then return false, i + 1
	elseif c == "t" then
		if depth > MAX_DEPTH then error("too deep", 0) end
		local t, n = {}, 0
		i = i + 1
		while s:sub(i, i) ~= "e" do
			if i > #s then error("unfinished table", 0) end
			local k, v
			k, i = des(s, i, depth + 1)
			if type(k) == "table" then error("table key", 0) end
			v, i = des(s, i, depth + 1)
			t[k] = v
			n = n + 1
			if n > 2000 then error("table too big", 0) end
		end
		return t, i + 1
	end
	error("unexpected '" .. c .. "'", 0)
end

function Share.Deserialize(s)
	local ok, v, after = pcall(des, s, 1, 0)
	if not ok then return nil, v end
	if after <= #s then return nil, "extra data" end
	return v
end

-- Base64 ------------------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DEC = {}
for i = 1, 64 do DEC[B64:sub(i, i)] = i - 1 end

function Share.Encode64(s)
	local out = {}
	for i = 1, #s, 3 do
		local a, b, c = s:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1, c2 = math.floor(n / 262144), math.floor(n / 4096) % 64
		local c3, c4 = math.floor(n / 64) % 64, n % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

function Share.Decode64(s)
	s = s:gsub("[^%w%+/=]", "")
	if #s % 4 ~= 0 then return nil end
	local out = {}
	for i = 1, #s, 4 do
		local q = { s:byte(i, i + 3) }
		local n, pad = 0, 0
		for j = 1, 4 do
			local ch = string.char(q[j])
			if ch == "=" then pad = pad + 1 n = n * 64
			else
				local d = DEC[ch]
				if not d or pad > 0 then return nil end
				n = n * 64 + d
			end
		end
		local bytes = string.char(math.floor(n / 65536), math.floor(n / 256) % 256, n % 256)
		out[#out + 1] = bytes:sub(1, 3 - pad)
	end
	return table.concat(out)
end

-- Sanitising --------------------------------------------------------------------------------

local function str(v, max)
	if type(v) ~= "string" then return nil end
	v = v:gsub("[%c|]", "") -- no control characters or UI escape codes
	if v == "" then return nil end
	return v:sub(1, max or MAX_STR)
end

local function num(v, lo, hi)
	if type(v) ~= "number" or v ~= v then return nil end
	if v < lo or v > hi then return nil end
	return v
end

local function int(v, lo, hi)
	v = num(v, lo, hi)
	return v and math.floor(v)
end

local function strList(v, n)
	if type(v) ~= "table" then return nil end
	local out = {}
	for i = 1, math.min(#v, n) do out[#out + 1] = str(v[i]) end
	return #out > 0 and out or nil
end

local function mats(v)
	if type(v) ~= "table" then return nil end
	local out = {}
	for i = 1, math.min(#v, MAX_MATS) do
		local m = v[i]
		if type(m) == "table" and str(m.name) then
			out[#out + 1] = { name = str(m.name), id = int(m.id, 1, 9999999), qty = int(m.qty, 1, 1000) or 1 }
		end
	end
	return out
end

local KINDS = { craft = true, tool = true, train = true, disenchant = true }
local SOURCES = { trainer = true, vendor = true, known = true, quest = true, drop = true }

local function source(v)
	if type(v) ~= "table" or not SOURCES[v.kind] then return nil end
	local out = { kind = v.kind, cost = int(v.cost, 0, 100000000), npc = str(v.npc),
		location = str(v.location), limited = v.limited == true or nil, rep = str(v.rep) }
	if type(v.vendors) == "table" then
		out.vendors = {}
		for i = 1, math.min(#v.vendors, 12) do
			local x = v.vendors[i]
			if type(x) == "table" and str(x.npc) then
				local side = (x.side == "Alliance" or x.side == "Horde") and x.side or nil
				out.vendors[#out.vendors + 1] = { npc = str(x.npc), location = str(x.location), side = side,
					cost = int(x.cost, 0, 100000000), limited = x.limited == true or nil }
			end
		end
		if #out.vendors == 0 then out.vendors = nil end
	end
	return out
end

local function step(v)
	if type(v) ~= "table" or not KINDS[v.kind] then return nil end
	local s = { kind = v.kind }
	if v.kind == "train" then
		s.rank = str(v.rank, 20)
		s.reqSkill = int(v.reqSkill, 0, 450)
		s.reqLevel = int(v.reqLevel, 0, 80)
		s.before = int(v.before, 1, 450)
		s.cap = int(v.cap, 1, 450)
		s.how = str(v.how, 200)
		if not (s.rank and s.before) then return nil end
		return s
	end
	s.from = int(v.from, 0, 450)
	s.to = int(v.to, 0, 450)
	s.note = str(v.note, 300)
	if v.kind == "disenchant" then
		if not (s.from and s.to and s.to > s.from) then return nil end
		return s
	end
	s.recipe = str(v.recipe)
	if not s.recipe then return nil end
	if v.kind == "craft" and not (s.from and s.to and s.to > s.from) then return nil end
	if type(v.colors) == "table" then
		local c = { int(v.colors[1], 0, 450), int(v.colors[2], 0, 450), int(v.colors[3], 0, 450), int(v.colors[4], 0, 450) }
		if c[1] and c[2] and c[3] and c[4] and c[1] <= c[2] and c[2] <= c[3] and c[3] <= c[4] then s.colors = c end
	end
	s.expected = int(v.expected, 0, 5000)
	s.safe = int(v.safe, 0, 5000)
	s.makes = int(v.makes, 1, 100)
	s.tools = strList(v.tools, 5)
	s.station = str(v.station, 40)
	s.mats = mats(v.mats)
	s.source = source(v.source)
	s.alts = strList(v.alts, 5)
	s.item = int(v.item, 1, 9999999)
	if type(v.items) == "table" then
		local list = {}
		for i = 1, math.min(#v.items, 8) do list[#list + 1] = int(v.items[i], 1, 9999999) end
		s.items = #list > 0 and list or nil
	end
	s.buy = v.buy == true or nil
	return s
end

-- Keep only what a guide may hold. Returns a clean guide or nil, reason.
function Share.Sanitize(g)
	if type(g) ~= "table" then return nil, "not a guide" end
	local out = {
		profession = str(g.profession, 40), name = str(g.name, 60), author = str(g.author, 40),
		from = int(g.from, 0, 450), to = int(g.to, 1, 450), note = str(g.note, 300),
		rev = int(g.rev, 0, 1000000),
	}
	if not out.profession then return nil, "no profession" end
	if not out.name then return nil, "no name" end
	if type(g.steps) ~= "table" or #g.steps == 0 then return nil, "no steps" end
	if #g.steps > MAX_STEPS then return nil, "too many steps" end
	out.steps = {}
	for i = 1, #g.steps do
		local s = step(g.steps[i])
		if s then out.steps[#out.steps + 1] = s end
	end
	if #out.steps == 0 then return nil, "no usable steps" end
	if type(g.parts) == "table" then
		local n = 0
		for name, p in pairs(g.parts) do
			n = n + 1
			if n > 20 then break end
			if str(name) and type(p) == "table" and str(p.recipe) then
				out.parts = out.parts or {}
				out.parts[str(name)] = { recipe = str(p.recipe), id = int(p.id, 1, 9999999),
					makes = int(p.makes, 1, 100) or 1, mats = mats(p.mats) }
			end
		end
	end
	-- range from the steps when missing or odd
	local lo, hi = 450, 0
	for _, s in ipairs(out.steps) do
		if s.from and s.from < lo then lo = s.from end
		if s.to and s.to > hi then hi = s.to end
	end
	out.from = out.from or (lo < 450 and lo or 1)
	out.to = out.to or (hi > 0 and hi or 300)
	if out.to <= out.from then return nil, "bad skill range" end
	return out
end

-- The fields a shared guide carries (not progress, not keys).
local EXPORT = { "profession", "name", "author", "from", "to", "note", "steps", "parts" }

function Share.Export(guide)
	local t = {}
	for _, k in ipairs(EXPORT) do t[k] = guide[k] end
	return PREFIX .. Share.Encode64(Share.Serialize(t))
end

-- Text pasted by the player: a clean guide, or nil and why not.
function Share.Import(text)
	if type(text) ~= "string" then return nil, "nothing pasted" end
	text = text:gsub("%s", "")
	if text:sub(1, #PREFIX) ~= PREFIX then return nil, "not a Craftbound guide (it starts with " .. PREFIX .. ")" end
	if #text > 400000 then return nil, "too long" end
	local raw = Share.Decode64(text:sub(#PREFIX + 1))
	if not raw then return nil, "the text is damaged (copy all of it)" end
	local t, err = Share.Deserialize(raw)
	if not t then return nil, "the text is damaged (" .. tostring(err) .. ")" end
	return Share.Sanitize(t)
end
