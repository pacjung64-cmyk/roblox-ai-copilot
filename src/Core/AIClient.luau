--!strict
--[[
  AIClient.luau
  Unified API client supporting Gemini, Groq, DeepSeek, Ollama, and OpenAI-compatible endpoints.
  Designed for testability via dependency-injected HttpService.
]]

local Types = require(script.Parent.Types)

local AIClient = {}
AIClient.__index = AIClient

export type HttpServiceInterface = {
	RequestAsync: (self: any, requestOptions: {
		Url: string,
		Method: string,
		Headers: { [string]: string }?,
		Body: string?,
	}) -> {
		Success: boolean,
		StatusCode: number,
		StatusMessage: string,
		Headers: { [string]: string },
		Body: string,
	},
	JSONEncode: (self: any, data: any) -> string,
	JSONDecode: (self: any, jsonString: string) -> any,
}

export type AIClientInstance = typeof(setmetatable({} :: {
	_settings: Types.Settings,
	_http: HttpServiceInterface,
}, AIClient))

function AIClient.new(settings: Types.Settings, customHttpService: HttpServiceInterface?): AIClientInstance
	local http: HttpServiceInterface
	if customHttpService then
		http = customHttpService
	else
		-- Roblox runtime fallback
		local ok, s = pcall(function()
			return game:GetService("HttpService") :: any
		end)
		if ok and s then
			http = s
		else
			error("HttpService not found. Pass customHttpService when running outside Roblox Studio.")
		end
	end

	return setmetatable({
		_settings = settings,
		_http = http,
	}, AIClient)
end

function AIClient:updateSettings(newSettings: Types.Settings)
	self._settings = newSettings
end

function AIClient:generate(prompt: string, systemPrompt: string): (boolean, string)
	local provider = self._settings.provider
	local apiKey = self._settings.apiKey
	local model = self._settings.model
	local temp = self._settings.temperature or 0.4

	if provider ~= "Ollama" and (not apiKey or apiKey == "") then
		return false, `API Key is missing for {provider}. Please configure your API key in Settings.`
	end

	local url: string
	local headers: { [string]: string } = {
		["Content-Type"] = "application/json",
	}
	local requestBodyTable: any

	if provider == "Gemini" then
		url = `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}`
		requestBodyTable = {
			contents = {
				{
					role = "user",
					parts = { { text = prompt } },
				},
			},
			systemInstruction = {
				parts = { { text = systemPrompt } },
			},
			generationConfig = {
				temperature = temp,
			},
		}
	elseif provider == "Groq" or provider == "DeepSeek" or provider == "Custom" then
		if provider == "Groq" then
			url = "https://api.groq.com/openai/v1/chat/completions"
		elseif provider == "DeepSeek" then
			url = "https://api.deepseek.com/chat/completions"
		else
			url = if self._settings.endpoint ~= "" then self._settings.endpoint else "http://localhost:8000/v1/chat/completions"
		end

		headers["Authorization"] = `Bearer {apiKey}`
		requestBodyTable = {
			model = model,
			messages = {
				{ role = "system", content = systemPrompt },
				{ role = "user", content = prompt },
			},
			temperature = temp,
		}
	elseif provider == "Ollama" then
		url = if self._settings.endpoint ~= "" then self._settings.endpoint else "http://127.0.0.1:11434/api/generate"
		requestBodyTable = {
			model = model,
			prompt = prompt,
			system = systemPrompt,
			stream = false,
		}
	else
		return false, `Unsupported provider: {tostring(provider)}`
	end

	local encodedBody: string
	local encodeOk, encodeErr = pcall(function()
		encodedBody = self._http:JSONEncode(requestBodyTable)
	end)
	if not encodeOk then
		return false, `JSON encoding failed: {tostring(encodeErr)}`
	end

	local response: any
	local reqOk, reqErr = pcall(function()
		response = self._http:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = headers,
			Body = encodedBody,
		})
	end)

	if not reqOk then
		local errMsg = tostring(reqErr)
		if string.find(errMsg, "Http requests are not enabled") then
			return false, "HttpService is disabled! In Roblox Studio, please open Game Settings -> Security -> Turn on 'Allow HTTP Requests'."
		end
		return false, `HTTP Request failed: {errMsg}`
	end

	if not response.Success or response.StatusCode >= 400 then
		local detail = response.Body or response.StatusMessage
		return false, `API returned error ({response.StatusCode}): {detail}`
	end

	-- Parse response based on provider
	local decoded: any
	local decodeOk, decodeErr = pcall(function()
		decoded = self._http:JSONDecode(response.Body)
	end)
	if not decodeOk then
		return false, `Failed to decode response JSON: {tostring(decodeErr)}`
	end

	if provider == "Gemini" then
		local candidate = decoded.candidates and decoded.candidates[1]
		local textPart = candidate and candidate.content and candidate.content.parts and candidate.content.parts[1]
		if textPart and textPart.text then
			return true, textPart.text
		else
			return false, "Gemini returned empty or filtered response."
		end
	elseif provider == "Groq" or provider == "DeepSeek" or provider == "Custom" then
		local choice = decoded.choices and decoded.choices[1]
		if choice and choice.message and choice.message.content then
			return true, choice.message.content
		else
			return false, "OpenAI-compatible endpoint returned empty response."
		end
	elseif provider == "Ollama" then
		if decoded.response then
			return true, decoded.response
		else
			return false, "Ollama returned empty response."
		end
	end

	return false, "Unknown error processing AI response."
end

-- Extracts code inside ```luau or ``` blocks
function AIClient.extractCodeBlock(rawText: string): string
	-- Try matching ```luau ... ```
	local luauPattern = "```luau%s*(.-)%s*```"
	local code = string.match(rawText, luauPattern)
	if code and #code > 0 then
		return code
	end

	-- Try matching ```lua ... ```
	local luaPattern = "```lua%s*(.-)%s*```"
	code = string.match(rawText, luaPattern)
	if code and #code > 0 then
		return code
	end

	-- Try matching generic ``` ... ```
	local genericPattern = "```%s*(.-)%s*```"
	code = string.match(rawText, genericPattern)
	if code and #code > 0 then
		return code
	end

	-- If no code blocks found, return raw trimmed text
	return rawText
end

-- Extracts and parses JSON inside ```json ... ```
function AIClient.extractJsonBlock(rawText: string, http: HttpServiceInterface): (boolean, any, string?)
	local jsonPattern = "```json%s*(.-)%s*```"
	local jsonText = string.match(rawText, jsonPattern)
	if not jsonText or #jsonText == 0 then
		-- Try finding { ... } directly
		local firstBrace = string.find(rawText, "{")
		local lastBrace = string.find(string.reverse(rawText), "}")
		if firstBrace and lastBrace then
			local actualLast = #rawText - lastBrace + 1
			jsonText = string.sub(rawText, firstBrace, actualLast)
		else
			jsonText = rawText
		end
	end

	local ok, decoded = pcall(function()
		return http:JSONDecode(jsonText)
	end)

	if not ok then
		return false, nil, `Failed to parse JSON: {tostring(decoded)}`
	end

	return true, decoded, nil
end

return AIClient
