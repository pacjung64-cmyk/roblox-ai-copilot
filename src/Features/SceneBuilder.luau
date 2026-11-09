--!strict
--[[
  SceneBuilder.luau
  Generates 3D procedural Roblox scenes and props in Workspace from natural language.
]]

local Types = require(script.Parent.Parent.Core.Types)
local PromptTemplates = require(script.Parent.Parent.Core.PromptTemplates)
local AIClient = require(script.Parent.Parent.Core.AIClient)

local SceneBuilder = {}
SceneBuilder.__index = SceneBuilder

export type SceneBuilderInstance = typeof(setmetatable({} :: {
	_client: any,
	_http: any,
}, SceneBuilder))

function SceneBuilder.new(client: any, httpService: any): SceneBuilderInstance
	return setmetatable({
		_client = client,
		_http = httpService,
	}, SceneBuilder)
end

function SceneBuilder:generateScene(prompt: string): (boolean, Types.SceneResult?, string?)
	local ok, rawResponse = self._client:generate(prompt, PromptTemplates.SCENE_BUILDER_SYSTEM)
	if not ok then
		return false, nil, rawResponse
	end

	local parseOk, sceneData, parseErr = AIClient.extractJsonBlock(rawResponse, self._http)
	if not parseOk or not sceneData then
		return false, nil, `Failed to parse AI scene specification: {tostring(parseErr)}`
	end

	return true, sceneData :: Types.SceneResult, nil
end

function SceneBuilder:buildInWorkspace(sceneResult: Types.SceneResult): (boolean, Model?, string?)
	local ok, err = pcall(function()
		local ChangeHistoryService = game:GetService("ChangeHistoryService")
		local Selection = game:GetService("Selection")
		local Workspace = game:GetService("Workspace")

		local sceneModel = Instance.new("Model")
		sceneModel.Name = sceneResult.sceneName or "AIScene"

		local partsList = sceneResult.parts or {}
		for _, partData in ipairs(partsList) do
			local part: BasePart
			local shape = string.lower(partData.shape or "block")

			if shape == "wedge" then
				part = Instance.new("WedgePart")
			else
				local p = Instance.new("Part")
				if shape == "cylinder" then
					p.Shape = Enum.PartType.Cylinder
				elseif shape == "ball" or shape == "sphere" then
					p.Shape = Enum.PartType.Ball
				else
					p.Shape = Enum.PartType.Block
				end
				part = p
			end

			-- Properties before parenting
			part.Name = partData.name or "Part"

			if partData.size and #partData.size >= 3 then
				part.Size = Vector3.new(partData.size[1], partData.size[2], partData.size[3])
			else
				part.Size = Vector3.new(4, 1, 4)
			end

			if partData.position and #partData.position >= 3 then
				part.Position = Vector3.new(partData.position[1], partData.position[2], partData.position[3])
			end

			if partData.rotation and #partData.rotation >= 3 then
				part.Orientation = Vector3.new(partData.rotation[1], partData.rotation[2], partData.rotation[3])
			end

			-- Material
			if partData.material then
				local matEnum = (Enum.Material :: any)[partData.material]
				if matEnum then
					part.Material = matEnum
				else
					part.Material = Enum.Material.SmoothPlastic
				end
			else
				part.Material = Enum.Material.SmoothPlastic
			end

			-- Color
			if partData.color and #partData.color >= 3 then
				part.Color = Color3.fromRGB(partData.color[1], partData.color[2], partData.color[3])
			end

			part.Anchored = if partData.anchored ~= nil then partData.anchored else true
			part.CanCollide = if partData.canCollide ~= nil then partData.canCollide else true
			part.Transparency = partData.transparency or 0

			-- Subtle point light for neon parts
			if part.Material == Enum.Material.Neon then
				local light = Instance.new("PointLight")
				light.Color = part.Color
				light.Range = math.max(part.Size.X, part.Size.Z) * 2
				light.Brightness = 1.2
				light.Parent = part
			end

			part.Parent = sceneModel
		end

		sceneModel.Parent = Workspace
		Selection:Set({ sceneModel })
		ChangeHistoryService:SetWaypoint(`AI Build {sceneModel.Name}`)
		return sceneModel
	end)

	if not ok then
		return false, nil, tostring(err)
	end

	return true, err :: any, nil
end

return SceneBuilder
