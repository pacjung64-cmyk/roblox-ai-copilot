--!strict
--[[
  init.server.luau
  Roblox AI Copilot - Main Plugin Entry Point.
  Initializes toolbar, dockable widget, and hotkey triggers in Roblox Studio.
]]

local PluginWidget = require(script.UI.PluginWidget)

local function main()
	local toolbar = plugin:CreateToolbar("Roblox AI Copilot")
	
	-- Create ribbon button
	local toggleButton = toolbar:CreateButton(
		"AICopilotToggle",
		"Open Roblox AI Copilot",
		"rbxassetid://10734887372", -- Built-in spark/AI icon asset
		"Roblox AI Copilot"
	)
	toggleButton.ClickableWhenViewportHidden = true

	local widget = PluginWidget.new(plugin)

	toggleButton.Click:Connect(function()
		widget:toggle()
	end)

	print([[
======================================================
  ⚡ Roblox AI Copilot v0.1.0 Loaded!
  • Multi-Engine: Gemini, Groq, DeepSeek, Ollama
  • Features: Script Gen | World Builder | Security Audit
  • Click the toolbar button or use dock widget to start.
======================================================]])
end

main()
