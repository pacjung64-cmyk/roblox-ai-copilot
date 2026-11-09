--!strict
--[[
  Types.luau
  Defines shared types for Roblox AI Copilot.
]]

export type Provider = "Gemini" | "Groq" | "DeepSeek" | "Ollama" | "Custom"

export type Settings = {
	provider: Provider,
	apiKey: string,
	model: string,
	endpoint: string,
	temperature: number,
}

export type ScriptType = "Server" | "Client" | "Module"

export type ScriptRequest = {
	prompt: string,
	scriptType: ScriptType,
	contextCode: string?,
	targetLocation: string?,
}

export type ScriptResult = {
	code: string,
	explanation: string,
	scriptType: ScriptType,
	suggestedName: string,
}

export type ScenePartData = {
	name: string,
	shape: string, -- "Block", "Cylinder", "Ball", "Wedge"
	size: { number }, -- [X, Y, Z]
	position: { number }, -- [X, Y, Z]
	rotation: { number }?, -- [X, Y, Z] in degrees
	material: string?, -- "Plastic", "SmoothPlastic", "Neon", "Wood", "Marble", etc.
	color: { number }?, -- [R, G, B] in 0-255
	anchored: boolean?,
	canCollide: boolean?,
	transparency: number?,
}

export type SceneResult = {
	sceneName: string,
	summary: string,
	parts: { ScenePartData },
}

export type SecuritySeverity = "Critical" | "High" | "Medium" | "Low"

export type SecurityFinding = {
	ruleId: string,
	severity: SecuritySeverity,
	line: number,
	codeSnippet: string,
	description: string,
	recommendation: string,
}

export type SecurityAuditResult = {
	score: number, -- 0-100
	totalIssues: number,
	findings: { SecurityFinding },
}

return {}
