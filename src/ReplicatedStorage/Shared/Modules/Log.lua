--!strict
-- Shared/Modules/Log.lua  (docs/16_technical_architecture.md §8)
--
-- Log.debug/info/warn/error(tag, message, ...). Every line is prefixed with the module tag: "[FrameService] ...".
-- debug prints only in Studio. warn and error always print. Log.error never throws: it reports in red and returns.

local RunService = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()

local Log = {}

local function format(tag: string, message: string, ...: any): string
	local text = message
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, message, ...)
		text = if ok then formatted else message .. " (bad format arguments)"
	end
	return "[" .. tag .. "] " .. text
end

function Log.debug(tag: string, message: string, ...: any)
	if IS_STUDIO then
		print(format(tag, message, ...))
	end
end

function Log.info(tag: string, message: string, ...: any)
	print(format(tag, message, ...))
end

function Log.warn(tag: string, message: string, ...: any)
	warn(format(tag, message, ...))
end

function Log.error(tag: string, message: string, ...: any)
	-- A separate thread, so the red error line appears in Output without unwinding the caller.
	task.spawn(error, format(tag, message, ...), 0)
end

-- Exposed for tests and for callers that need the formatted text (e.g. toasts in Studio).
Log.format = format

return Log
