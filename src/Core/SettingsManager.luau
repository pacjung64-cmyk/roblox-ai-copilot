--!strict
--[[
  SettingsManager.luau
  Manages persistent plugin configurations and defaults.
]]

local Types = require(script.Parent.Types)

local DEFAULT_SETTINGS: Types.Settings = {
	provider = "Gemini",
	apiKey = "",
	model = "gemini-1.5-flash",
	endpoint = "",
	temperature = 0.4,
}

local SETTINGS_KEY = "RobloxAICopilot_Settings_v1"

local SettingsManager = {}
SettingsManager.__index = SettingsManager

export type SettingsManagerInstance = typeof(setmetatable({} :: {
	_plugin: any?,
	_settings: Types.Settings,
}, SettingsManager))

function SettingsManager.new(pluginInstance: any?): SettingsManagerInstance
	local self = setmetatable({
		_plugin = pluginInstance,
		_settings = table.clone(DEFAULT_SETTINGS),
	}, SettingsManager)

	self:load()
	return self
end

function SettingsManager:load(): Types.Settings
	if self._plugin and typeof(self._plugin.GetSetting) == "function" then
		local ok, saved = pcall(function()
			return self._plugin:GetSetting(SETTINGS_KEY)
		end)
		if ok and typeof(saved) == "table" then
			for k, v in pairs(saved) do
				(self._settings :: any)[k] = v
			end
		end
	end
	return self._settings
end

function SettingsManager:save(newSettings: Types.Settings): boolean
	for k, v in pairs(newSettings) do
		(self._settings :: any)[k] = v
	end

	if self._plugin and typeof(self._plugin.SetSetting) == "function" then
		local ok, err = pcall(function()
			self._plugin:SetSetting(SETTINGS_KEY, self._settings)
		end)
		if not ok then
			warn("[Roblox AI Copilot] Failed to save settings: " .. tostring(err))
			return false
		end
	end
	return true
end

function SettingsManager:get(): Types.Settings
	return table.clone(self._settings)
end

function SettingsManager:getDefaults(): Types.Settings
	return table.clone(DEFAULT_SETTINGS)
end

function SettingsManager:getDefaultModel(provider: Types.Provider): string
	if provider == "Gemini" then
		return "gemini-1.5-flash"
	elseif provider == "Groq" then
		return "llama-3.3-70b-versatile"
	elseif provider == "DeepSeek" then
		return "deepseek-coder"
	elseif provider == "Ollama" then
		return "qwen2.5-coder:7b"
	else
		return "custom-model"
	end
end

return SettingsManager
