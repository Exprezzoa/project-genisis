-- tools/studio_helpers.lua  -  paste into the MCP run-code tool (Edit datamodel) after every Studio restart.
-- Defines the push helpers used with tools/serve.ps1 (which serves src/ and builders/ at http://127.0.0.1:8123/):
--   _G.PG_pull({ { "src/.../File.lua", "Service.Path.To.Instance", "Module" | "Server" | "Client" }, ... })
--       fetches each file, creates the instance (and missing folders) if needed, sets .Source, and returns
--       "<path> <bytes> <adler32>" lines to compare with tools/checksum.ps1
--   _G.PG_sumText(text) -> bytes, adler32 (CRLF normalized)      _G.PG_resolve(path, kind)      _G.PG_put(path, kind, source)

local HttpService = game:GetService("HttpService")
_G.PG_sumText = function(text)
	text = text:gsub("\r\n", "\n")
	local a, b = 1, 0
	for i = 1, #text do
		a = (a + string.byte(text, i)) % 65521
		b = (b + a) % 65521
	end
	return #text, b * 65536 + a
end
_G.PG_resolve = function(path, kind)
	local parts = string.split(path, ".")
	local current = game:GetService(parts[1])
	for i = 2, #parts do
		local child = current:FindFirstChild(parts[i])
		if not child then
			if i < #parts then
				child = Instance.new("Folder")
			elseif kind == "Server" then
				child = Instance.new("Script")
			elseif kind == "Client" then
				child = Instance.new("LocalScript")
			else
				child = Instance.new("ModuleScript")
			end
			child.Name = parts[i]
			child.Parent = current
		end
		current = child
	end
	return current
end
_G.PG_put = function(path, kind, source)
	local inst = _G.PG_resolve(path, kind)
	inst.Source = source
	return inst
end
_G.PG_pull = function(list)
	local out = {}
	for _, item in ipairs(list) do
		local res = HttpService:RequestAsync({ Url = "http://127.0.0.1:8123/" .. item[1], Method = "GET" })
		if not res.Success then
			table.insert(out, item[2] .. " FAILED " .. tostring(res.StatusCode))
		else
			local inst = _G.PG_put(item[2], item[3], res.Body)
			local bytes, sum = _G.PG_sumText(inst.Source)
			table.insert(out, string.format("%s %d %d", item[2], bytes, sum))
		end
	end
	return table.concat(out, "\n")
end
return "helpers ready"
