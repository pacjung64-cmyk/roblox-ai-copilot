--!strict
--[[
  ScriptGenerator.luau
  Generates production-grade, typed, exploit-resistant Luau scripts and inserts them into Studio.
]]

local Types = require(script.Parent.Parent.Core.Types)
local PromptTemplates = require(script.Parent.Parent.Core.PromptTemplates)
local AIClient = require(script.Parent.Parent.Core.AIClient)

local ScriptGenerator = {}
ScriptGenerator.__index = ScriptGenerator

export type ScriptGeneratorInstance = typeof(setmetatable({} :: {
	_client: any,
}, ScriptGenerator))

function ScriptGenerator.new(client: any): ScriptGeneratorInstance
	return setmetatable({
		_client = client,
	}, ScriptGenerator)
end

function ScriptGenerator:generateScript(request: Types.ScriptRequest): (boolean, Types.ScriptResult?, string?)
	local scriptType = request.scriptType or "Server"
	local userPrompt = `Target Script Type: {scriptType} Script\nUser Request: {request.prompt}`
	
	if request.contextCode and request.contextCode ~= "" then
		userPrompt ..= `\n\nExisting Code / Context:\n\`\`\`luau\n{request.contextCode}\n\`\`\``
	end

	local ok, rawResponse = self._client:generate(userPrompt, PromptTemplates.LUAU_EXPERT_SYSTEM)
	if not ok then
		return false, nil, rawResponse
	end

	local cleanCode = AIClient.extractCodeBlock(rawResponse)
	
	-- Determine suggested name
	local suggestedName = "AIScript"
	local promptLower = string.lower(request.prompt)
	if string.find(promptLower, "leaderstat") or string.find(promptLower, "coin") then
		suggestedName = "LeaderstatsManager"
	elseif string.find(promptLower, "combat") or string.find(promptLower, "dash") or string.find(promptLower, "sword") then
		suggestedName = "CombatController"
	elseif string.find(promptLower, "datastore") or string.find(promptLower, "save") then
		suggestedName = "PlayerDataStore"
	elseif string.find(promptLower, "inventory") then
		suggestedName = "InventoryHandler"
	elseif string.find(promptLower, "door") then
		suggestedName = "DoorSystem"
	end

	if scriptType == "Client" then
		suggestedName ..= "Client"
	end

	return true, {
		code = cleanCode,
		explanation = rawResponse,
		scriptType = scriptType,
		suggestedName = suggestedName,
	}, nil
end

function ScriptGenerator:insertIntoStudio(result: Types.ScriptResult, targetParent: Instance?): (boolean, Instance?, string?)
	local ok, err = pcall(function()
		local ChangeHistoryService = game:GetService("ChangeHistoryService")
		local Selection = game:GetService("Selection")

		local newInstance: Instance
		if result.scriptType == "Server" then
			local s = Instance.new("Script")
			s.Source = result.code
			newInstance = s
		elseif result.scriptType == "Client" then
			local s = Instance.new("LocalScript")
			s.Source = result.code
			newInstance = s
		else
			local s = Instance.new("ModuleScript")
			s.Source = result.code
			newInstance = s
		end

		newInstance.Name = result.suggestedName

		-- Determine smart parent if targetParent is nil
		local parent = targetParent
		if not parent then
			if result.scriptType == "Server" then
				parent = game:GetService("ServerScriptService")
			elseif result.scriptType == "Client" then
				local starterPlayer = game:GetService("StarterPlayer")
				parent = starterPlayer:FindFirstChild("StarterPlayerScripts") or starterPlayer
			else
				parent = game:GetService("ReplicatedStorage")
			end
		end

		newInstance.Parent = parent
		Selection:Set({ newInstance })
		ChangeHistoryService:SetWaypoint(`AI Insert {result.suggestedName}`)
		return newInstance
	end)

	if not ok then
		return false, nil, tostring(err)
	end

	return true, err :: any, nil
end

return ScriptGenerator
