--!strict
--[[
  PluginWidget.luau
  Studio Dockable Widget UI with Theme awareness (Dark/Light), Tabs, and Studio Actions.
]]

local Types = require(script.Parent.Parent.Core.Types)
local SettingsManager = require(script.Parent.Parent.Core.SettingsManager)
local AIClient = require(script.Parent.Parent.Core.AIClient)
local ScriptGenerator = require(script.Parent.Parent.Features.ScriptGenerator)
local SceneBuilder = require(script.Parent.Parent.Features.SceneBuilder)
local SecurityAuditor = require(script.Parent.Parent.Features.SecurityAuditor)

local PluginWidget = {}
PluginWidget.__index = PluginWidget

export type PluginWidgetInstance = typeof(setmetatable({} :: {
	_plugin: Plugin,
	_widget: DockWidgetPluginGui,
	_settingsMgr: any,
	_client: any,
	_scriptGen: any,
	_sceneBuilder: any,
	_securityAuditor: any,
	_activeTab: string,
	_lastScriptResult: Types.ScriptResult?,
	_lastSceneResult: Types.SceneResult?,
	_container: Frame,
}, PluginWidget))

function PluginWidget.new(pluginInstance: Plugin): PluginWidgetInstance
	local settingsMgr = SettingsManager.new(pluginInstance)
	local currentSettings = settingsMgr:get()

	local httpService = game:GetService("HttpService")
	local client = AIClient.new(currentSettings, httpService)
	local scriptGen = ScriptGenerator.new(client)
	local sceneBuilder = SceneBuilder.new(client, httpService)
	local securityAuditor = SecurityAuditor.new(client)

	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false, -- init enabled
		false, -- override previous enabled state
		360, -- default width
		520, -- default height
		300, -- min width
		400 -- min height
	)

	local widget = pluginInstance:CreateDockWidgetPluginGui("RobloxAICopilot_Widget_v1", widgetInfo)
	widget.Title = "Roblox AI Copilot"
	widget.Name = "RobloxAICopilotGui"

	local self = setmetatable({
		_plugin = pluginInstance,
		_widget = widget,
		_settingsMgr = settingsMgr,
		_client = client,
		_scriptGen = scriptGen,
		_sceneBuilder = sceneBuilder,
		_securityAuditor = securityAuditor,
		_activeTab = "ScriptGen",
		_lastScriptResult = nil,
		_lastSceneResult = nil,
		_container = (nil :: any),
	}, PluginWidget)

	self:_buildInterface()
	return self
end

function PluginWidget:toggle()
	self._widget.Enabled = not self._widget.Enabled
end

function PluginWidget:_getThemeColors()
	local studioTheme = settings().Studio.Theme
	local isDark = studioTheme.Name == "Dark"

	return {
		bg = if isDark then Color3.fromRGB(30, 30, 30) else Color3.fromRGB(245, 245, 245),
		surface = if isDark then Color3.fromRGB(37, 37, 38) else Color3.fromRGB(255, 255, 255),
		cardBg = if isDark then Color3.fromRGB(45, 45, 48) else Color3.fromRGB(235, 235, 238),
		border = if isDark then Color3.fromRGB(60, 60, 60) else Color3.fromRGB(200, 200, 200),
		text = if isDark then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(20, 20, 20),
		textMuted = if isDark then Color3.fromRGB(150, 150, 150) else Color3.fromRGB(110, 110, 110),
		accent = Color3.fromRGB(0, 162, 255), -- Roblox Studio Blue
		accentHover = Color3.fromRGB(28, 178, 255),
		success = Color3.fromRGB(46, 204, 113),
		warning = Color3.fromRGB(241, 196, 15),
		danger = Color3.fromRGB(231, 76, 60),
	}
end

function PluginWidget:_buildInterface()
	local colors = self:_getThemeColors()

	local root = Instance.new("Frame")
	root.Name = "RootFrame"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundColor3 = colors.bg
	root.BorderSizePixel = 0
	root.Parent = self._widget

	-- Top Tab Bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.BackgroundColor3 = colors.surface
	tabBar.BorderSizePixel = 0
	tabBar.Parent = root

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 2)
	tabLayout.Parent = tabBar

	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Position = UDim2.new(0, 0, 0, 36)
	contentContainer.Size = UDim2.new(1, 0, 1, -36)
	contentContainer.BackgroundColor3 = colors.bg
	contentContainer.BorderSizePixel = 0
	contentContainer.Parent = root
	self._container = contentContainer

	local tabs = {
		{ id = "ScriptGen", name = "⚡ Script" },
		{ id = "SceneBuilder", name = "🏗️ World" },
		{ id = "Security", name = "🛡️ Audit" },
		{ id = "Settings", name = "⚙️ Config" },
	}

	local tabButtons: { [string]: TextButton } = {}

	for idx, tabInfo in ipairs(tabs) do
		local btn = Instance.new("TextButton")
		btn.Name = "Tab_" .. tabInfo.id
		btn.Size = UDim2.new(0.25, -2, 1, 0)
		btn.Text = tabInfo.name
		btn.Font = Enum.Font.SourceSansBold
		btn.TextSize = 13
		btn.BorderSizePixel = 0
		btn.BackgroundColor3 = if tabInfo.id == self._activeTab then colors.cardBg else colors.surface
		btn.TextColor3 = if tabInfo.id == self._activeTab then colors.accent else colors.textMuted
		btn.LayoutOrder = idx
		btn.Parent = tabBar

		tabButtons[tabInfo.id] = btn

		btn.MouseButton1Click:Connect(function()
			self._activeTab = tabInfo.id
			for id, b in pairs(tabButtons) do
				b.BackgroundColor3 = if id == self._activeTab then colors.cardBg else colors.surface
				b.TextColor3 = if id == self._activeTab then colors.accent else colors.textMuted
			end
			self:_renderActiveTab()
		end)
	end

	-- Studio Theme Changed connection
	settings().Studio.ThemeChanged:Connect(function()
		colors = self:_getThemeColors()
		root.BackgroundColor3 = colors.bg
		tabBar.BackgroundColor3 = colors.surface
		contentContainer.BackgroundColor3 = colors.bg
		self:_renderActiveTab()
	end)

	self:_renderActiveTab()
end

function PluginWidget:_renderActiveTab()
	self._container:ClearAllChildren()
	local colors = self:_getThemeColors()

	if self._activeTab == "ScriptGen" then
		self:_renderScriptGenTab(colors)
	elseif self._activeTab == "SceneBuilder" then
		self:_renderSceneBuilderTab(colors)
	elseif self._activeTab == "Security" then
		self:_renderSecurityTab(colors)
	elseif self._activeTab == "Settings" then
		self:_renderSettingsTab(colors)
	end
end

-- Tab 1: Script Generator
function PluginWidget:_renderScriptGenTab(colors: any)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -16)
	scroll.Position = UDim2.new(0, 8, 0, 8)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 560)
	scroll.Parent = self._container

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	-- Prompt Input
	local promptBox = Instance.new("TextBox")
	promptBox.Size = UDim2.new(1, 0, 0, 70)
	promptBox.PlaceholderText = "Describe your script (e.g. 'DataStore coins system with anti-exploit' or 'Double-jump with trail VFX')..."
	promptBox.Text = ""
	promptBox.MultiLine = true
	promptBox.ClearTextOnFocus = false
	promptBox.TextWrapped = true
	promptBox.Font = Enum.Font.SourceSans
	promptBox.TextSize = 13
	promptBox.BackgroundColor3 = colors.cardBg
	promptBox.TextColor3 = colors.text
	promptBox.PlaceholderColor3 = colors.textMuted
	promptBox.Parent = scroll

	-- Script Type Selector
	local selectedType: Types.ScriptType = "Server"
	local typeRow = Instance.new("Frame")
	typeRow.Size = UDim2.new(1, 0, 0, 28)
	typeRow.BackgroundTransparency = 1
	typeRow.Parent = scroll

	local typeLayout = Instance.new("UIListLayout")
	typeLayout.FillDirection = Enum.FillDirection.Horizontal
	typeLayout.Padding = UDim.new(0, 4)
	typeLayout.Parent = typeRow

	local typeButtons: { [string]: TextButton } = {}
	for _, st in ipairs({ "Server", "Client", "Module" }) do
		local tb = Instance.new("TextButton")
		tb.Size = UDim2.new(0.33, -4, 1, 0)
		tb.Text = st
		tb.Font = Enum.Font.SourceSansBold
		tb.TextSize = 12
		tb.BackgroundColor3 = if st == selectedType then colors.accent else colors.cardBg
		tb.TextColor3 = if st == selectedType then Color3.new(1, 1, 1) else colors.textMuted
		tb.Parent = typeRow
		typeButtons[st] = tb

		tb.MouseButton1Click:Connect(function()
			selectedType = st :: Types.ScriptType
			for tName, btn in pairs(typeButtons) do
				btn.BackgroundColor3 = if tName == selectedType then colors.accent else colors.cardBg
				btn.TextColor3 = if tName == selectedType then Color3.new(1, 1, 1) else colors.textMuted
			end
		end)
	end

	-- Status label
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Ready to generate"
	statusLabel.TextColor3 = colors.textMuted
	statusLabel.Font = Enum.Font.SourceSansItalic
	statusLabel.TextSize = 12
	statusLabel.Parent = scroll

	-- Generate Button
	local genBtn = Instance.new("TextButton")
	genBtn.Size = UDim2.new(1, 0, 0, 32)
	genBtn.Text = "✨ Generate Luau Script"
	genBtn.BackgroundColor3 = colors.accent
	genBtn.TextColor3 = Color3.new(1, 1, 1)
	genBtn.Font = Enum.Font.SourceSansBold
	genBtn.TextSize = 14
	genBtn.Parent = scroll

	-- Code Preview
	local previewBox = Instance.new("TextBox")
	previewBox.Size = UDim2.new(1, 0, 0, 240)
	previewBox.BackgroundColor3 = colors.cardBg
	previewBox.TextColor3 = colors.text
	previewBox.Font = Enum.Font.Code
	previewBox.TextSize = 11
	previewBox.ClearTextOnFocus = false
	previewBox.MultiLine = true
	previewBox.TextWrapped = false
	previewBox.Text = "-- Generated Luau script will appear here"
	previewBox.Parent = scroll

	-- Action buttons row (Insert & Copy)
	local actionRow = Instance.new("Frame")
	actionRow.Size = UDim2.new(1, 0, 0, 32)
	actionRow.BackgroundTransparency = 1
	actionRow.Parent = scroll

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.Padding = UDim.new(0, 6)
	actionLayout.Parent = actionRow

	local insertBtn = Instance.new("TextButton")
	insertBtn.Size = UDim2.new(0.65, -3, 1, 0)
	insertBtn.Text = "🚀 Insert into Game (Ctrl+Z)"
	insertBtn.BackgroundColor3 = colors.success
	insertBtn.TextColor3 = Color3.new(1, 1, 1)
	insertBtn.Font = Enum.Font.SourceSansBold
	insertBtn.TextSize = 13
	insertBtn.Parent = actionRow

	local copyBtn = Instance.new("TextButton")
	copyBtn.Size = UDim2.new(0.35, -3, 1, 0)
	copyBtn.Text = "📋 Copy Code"
	copyBtn.BackgroundColor3 = colors.cardBg
	copyBtn.TextColor3 = colors.text
	copyBtn.Font = Enum.Font.SourceSansBold
	copyBtn.TextSize = 12
	copyBtn.Parent = actionRow

	genBtn.MouseButton1Click:Connect(function()
		local prompt = promptBox.Text
		if prompt == "" then
			statusLabel.Text = "⚠️ Please write a prompt first!"
			statusLabel.TextColor3 = colors.warning
			return
		end

		statusLabel.Text = "⏳ Generating typed Luau code via AI..."
		statusLabel.TextColor3 = colors.accent
		genBtn.Active = false

		task.spawn(function()
			local ok, result, err = self._scriptGen:generateScript({
				prompt = prompt,
				scriptType = selectedType,
			})

			genBtn.Active = true
			if ok and result then
				self._lastScriptResult = result
				previewBox.Text = result.code
				statusLabel.Text = `✅ Generated {result.suggestedName} successfully!`
				statusLabel.TextColor3 = colors.success
			else
				statusLabel.Text = `❌ Error: {tostring(err)}`
				statusLabel.TextColor3 = colors.danger
			end
		end)
	end)

	insertBtn.MouseButton1Click:Connect(function()
		if not self._lastScriptResult then
			statusLabel.Text = "⚠️ No script generated yet!"
			statusLabel.TextColor3 = colors.warning
			return
		end

		-- Insert into Studio
		local ok, ins, err = self._scriptGen:insertIntoStudio(self._lastScriptResult)
		if ok and ins then
			statusLabel.Text = `🎉 Inserted {ins.Name} into {ins.Parent.Name}!`
			statusLabel.TextColor3 = colors.success
		else
			statusLabel.Text = `❌ Insert failed: {tostring(err)}`
			statusLabel.TextColor3 = colors.danger
		end
	end)

	copyBtn.MouseButton1Click:Connect(function()
		-- In Studio plugin, clipboard access is limited, but we can display status
		statusLabel.Text = "💡 Tip: Select text in preview box and press Ctrl+C"
		statusLabel.TextColor3 = colors.accent
	end)
end

-- Tab 2: Scene Builder
function PluginWidget:_renderSceneBuilderTab(colors: any)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -16)
	scroll.Position = UDim2.new(0, 8, 0, 8)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 480)
	scroll.Parent = self._container

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	local promptBox = Instance.new("TextBox")
	promptBox.Size = UDim2.new(1, 0, 0, 70)
	promptBox.PlaceholderText = "Describe 3D scene (e.g. 'Circular gladiator arena with 8 marble pillars and central spawn pad' or 'Cyberpunk alley with neon signs')..."
	promptBox.Text = ""
	promptBox.MultiLine = true
	promptBox.TextWrapped = true
	promptBox.Font = Enum.Font.SourceSans
	promptBox.TextSize = 13
	promptBox.BackgroundColor3 = colors.cardBg
	promptBox.TextColor3 = colors.text
	promptBox.PlaceholderColor3 = colors.textMuted
	promptBox.Parent = scroll

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Ready to build in Workspace"
	statusLabel.TextColor3 = colors.textMuted
	statusLabel.Font = Enum.Font.SourceSansItalic
	statusLabel.TextSize = 12
	statusLabel.Parent = scroll

	local buildBtn = Instance.new("TextButton")
	buildBtn.Size = UDim2.new(1, 0, 0, 36)
	buildBtn.Text = "🏗️ Build Scene in Workspace"
	buildBtn.BackgroundColor3 = colors.accent
	buildBtn.TextColor3 = Color3.new(1, 1, 1)
	buildBtn.Font = Enum.Font.SourceSansBold
	buildBtn.TextSize = 14
	buildBtn.Parent = scroll

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Size = UDim2.new(1, 0, 0, 260)
	resultLabel.BackgroundColor3 = colors.cardBg
	resultLabel.TextColor3 = colors.text
	resultLabel.Font = Enum.Font.Code
	resultLabel.TextSize = 11
	resultLabel.TextWrapped = true
	resultLabel.TextYAlignment = Enum.TextYAlignment.Top
	resultLabel.Text = "Scene specification and generated parts will appear here..."
	resultLabel.Parent = scroll

	buildBtn.MouseButton1Click:Connect(function()
		local prompt = promptBox.Text
		if prompt == "" then
			statusLabel.Text = "⚠️ Please write a scene description!"
			statusLabel.TextColor3 = colors.warning
			return
		end

		statusLabel.Text = "⏳ Translating prompt into 3D instances..."
		statusLabel.TextColor3 = colors.accent
		buildBtn.Active = false

		task.spawn(function()
			local ok, sceneData, err = self._sceneBuilder:generateScene(prompt)
			if ok and sceneData then
				self._lastSceneResult = sceneData
				local partCount = if sceneData.parts then #sceneData.parts else 0
				resultLabel.Text = `Scene: {sceneData.sceneName or "AIScene"}\nSummary: {sceneData.summary or ""}\nTotal Parts: {partCount}\nBuilding into Workspace now...`

				local bOk, model, bErr = self._sceneBuilder:buildInWorkspace(sceneData)
				buildBtn.Active = true

				if bOk and model then
					statusLabel.Text = `🎉 Successfully built '{model.Name}' with {partCount} parts!`
					statusLabel.TextColor3 = colors.success
				else
					statusLabel.Text = `❌ Workspace build error: {tostring(bErr)}`
					statusLabel.TextColor3 = colors.danger
				end
			else
				buildBtn.Active = true
				statusLabel.Text = `❌ Scene generation error: {tostring(err)}`
				statusLabel.TextColor3 = colors.danger
			end
		end)
	end)
end

-- Tab 3: Security & Exploit Auditor
function PluginWidget:_renderSecurityTab(colors: any)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -16)
	scroll.Position = UDim2.new(0, 8, 0, 8)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 600)
	scroll.Parent = self._container

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	local auditBtn = Instance.new("TextButton")
	auditBtn.Size = UDim2.new(1, 0, 0, 34)
	auditBtn.Text = "🔍 Scan Selected Script in Explorer"
	auditBtn.BackgroundColor3 = colors.accent
	auditBtn.TextColor3 = Color3.new(1, 1, 1)
	auditBtn.Font = Enum.Font.SourceSansBold
	auditBtn.TextSize = 13
	auditBtn.Parent = scroll

	local scoreBadge = Instance.new("TextLabel")
	scoreBadge.Size = UDim2.new(1, 0, 0, 40)
	scoreBadge.BackgroundColor3 = colors.cardBg
	scoreBadge.Text = "Security Score: -- / 100"
	scoreBadge.Font = Enum.Font.SourceSansBold
	scoreBadge.TextSize = 18
	scoreBadge.TextColor3 = colors.text
	scoreBadge.Parent = scroll

	local reportBox = Instance.new("TextLabel")
	reportBox.Size = UDim2.new(1, 0, 0, 360)
	reportBox.BackgroundColor3 = colors.cardBg
	reportBox.TextColor3 = colors.text
	reportBox.Font = Enum.Font.SourceSans
	reportBox.TextSize = 12
	reportBox.TextWrapped = true
	reportBox.TextYAlignment = Enum.TextYAlignment.Top
	reportBox.Text = "Select a Script in Explorer and click 'Scan Selected Script' to detect exploits and bugs."
	reportBox.Parent = scroll

	auditBtn.MouseButton1Click:Connect(function()
		local Selection = game:GetService("Selection")
		local selected = Selection:Get()
		if #selected == 0 or not selected[1]:IsA("LuaSourceContainer") then
			reportBox.Text = "⚠️ Please select a Script, LocalScript, or ModuleScript in the Explorer window!"
			scoreBadge.TextColor3 = colors.warning
			return
		end

		local scriptInstance = selected[1] :: LuaSourceContainer
		local code = scriptInstance.Source

		-- Step 1: Fast local static scan
		local scanResult = SecurityAuditor.staticScan(code)
		scoreBadge.Text = `Security Score: {scanResult.score} / 100`

		if scanResult.score >= 80 then
			scoreBadge.TextColor3 = colors.success
		elseif scanResult.score >= 50 then
			scoreBadge.TextColor3 = colors.warning
		else
			scoreBadge.TextColor3 = colors.danger
		end

		local report = `Target: {scriptInstance.Name} ({#scanResult.findings} issues found)\n\n`
		for i, f in ipairs(scanResult.findings) do
			report ..= `[{f.severity}] Line {f.line}: {f.description}\n→ Fix: {f.recommendation}\n\n`
		end

		if #scanResult.findings == 0 then
			report ..= "✨ No known static anti-patterns found! Clean and compliant."
		end

		reportBox.Text = report
	end)
end

-- Tab 4: Settings
function PluginWidget:_renderSettingsTab(colors: any)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -16)
	scroll.Position = UDim2.new(0, 8, 0, 8)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 480)
	scroll.Parent = self._container

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	local currentSettings = self._settingsMgr:get()

	-- Provider Selector Label
	local provLabel = Instance.new("TextLabel")
	provLabel.Size = UDim2.new(1, 0, 0, 20)
	provLabel.BackgroundTransparency = 1
	provLabel.Text = "AI Provider:"
	provLabel.Font = Enum.Font.SourceSansBold
	provLabel.TextSize = 13
	provLabel.TextColor3 = colors.text
	provLabel.TextXAlignment = Enum.TextXAlignment.Left
	provLabel.Parent = scroll

	local providerRow = Instance.new("Frame")
	providerRow.Size = UDim2.new(1, 0, 0, 28)
	providerRow.BackgroundTransparency = 1
	providerRow.Parent = scroll

	local pLayout = Instance.new("UIListLayout")
	pLayout.FillDirection = Enum.FillDirection.Horizontal
	pLayout.Padding = UDim.new(0, 4)
	pLayout.Parent = providerRow

	local selectedProvider: Types.Provider = currentSettings.provider
	local pButtons: { [string]: TextButton } = {}

	for _, pName in ipairs({ "Gemini", "Groq", "DeepSeek", "Ollama" }) do
		local pb = Instance.new("TextButton")
		pb.Size = UDim2.new(0.25, -4, 1, 0)
		pb.Text = pName
		pb.Font = Enum.Font.SourceSansBold
		pb.TextSize = 12
		pb.BackgroundColor3 = if pName == selectedProvider then colors.accent else colors.cardBg
		pb.TextColor3 = if pName == selectedProvider then Color3.new(1, 1, 1) else colors.textMuted
		pb.Parent = providerRow
		pButtons[pName] = pb

		pb.MouseButton1Click:Connect(function()
			selectedProvider = pName :: Types.Provider
			for n, b in pairs(pButtons) do
				b.BackgroundColor3 = if n == selectedProvider then colors.accent else colors.cardBg
				b.TextColor3 = if n == selectedProvider then Color3.new(1, 1, 1) else colors.textMuted
			end
		end)
	end

	-- API Key
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.new(1, 0, 0, 20)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = "API Key (Stored locally in Studio settings):"
	keyLabel.Font = Enum.Font.SourceSansBold
	keyLabel.TextSize = 13
	keyLabel.TextColor3 = colors.text
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.Parent = scroll

	local keyBox = Instance.new("TextBox")
	keyBox.Size = UDim2.new(1, 0, 0, 30)
	keyBox.BackgroundColor3 = colors.cardBg
	keyBox.TextColor3 = colors.text
	keyBox.Font = Enum.Font.Code
	keyBox.TextSize = 12
	keyBox.Text = currentSettings.apiKey or ""
	keyBox.PlaceholderText = "Paste Gemini / Groq / DeepSeek API key here..."
	keyBox.PlaceholderColor3 = colors.textMuted
	keyBox.Parent = scroll

	-- Model Name
	local modelLabel = Instance.new("TextLabel")
	modelLabel.Size = UDim2.new(1, 0, 0, 20)
	modelLabel.BackgroundTransparency = 1
	modelLabel.Text = "Model Name:"
	modelLabel.Font = Enum.Font.SourceSansBold
	modelLabel.TextSize = 13
	modelLabel.TextColor3 = colors.text
	modelLabel.TextXAlignment = Enum.TextXAlignment.Left
	modelLabel.Parent = scroll

	local modelBox = Instance.new("TextBox")
	modelBox.Size = UDim2.new(1, 0, 0, 30)
	modelBox.BackgroundColor3 = colors.cardBg
	modelBox.TextColor3 = colors.text
	modelBox.Font = Enum.Font.Code
	modelBox.TextSize = 12
	modelBox.Text = currentSettings.model or self._settingsMgr:getDefaultModel(selectedProvider)
	modelBox.Parent = scroll

	-- Save Status
	local saveStatus = Instance.new("TextLabel")
	saveStatus.Size = UDim2.new(1, 0, 0, 20)
	saveStatus.BackgroundTransparency = 1
	saveStatus.Text = ""
	saveStatus.TextColor3 = colors.success
	saveStatus.Font = Enum.Font.SourceSans
	saveStatus.TextSize = 12
	saveStatus.Parent = scroll

	-- Save Button
	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(1, 0, 0, 34)
	saveBtn.Text = "💾 Save Settings"
	saveBtn.BackgroundColor3 = colors.accent
	saveBtn.TextColor3 = Color3.new(1, 1, 1)
	saveBtn.Font = Enum.Font.SourceSansBold
	saveBtn.TextSize = 14
	saveBtn.Parent = scroll

	saveBtn.MouseButton1Click:Connect(function()
		local updated: Types.Settings = {
			provider = selectedProvider,
			apiKey = keyBox.Text,
			model = modelBox.Text,
			endpoint = currentSettings.endpoint or "",
			temperature = currentSettings.temperature or 0.4,
		}

		self._settingsMgr:save(updated)
		self._client:updateSettings(updated)
		saveStatus.Text = "✅ Settings saved successfully!"
		saveStatus.TextColor3 = colors.success
	end)
end

return PluginWidget
