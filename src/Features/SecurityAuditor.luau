--!strict
--[[
  SecurityAuditor.luau
  Performs hybrid static heuristic scans and deep AI exploit audits on Luau code.
]]

local Types = require(script.Parent.Parent.Core.Types)
local PromptTemplates = require(script.Parent.Parent.Core.PromptTemplates)

local SecurityAuditor = {}
SecurityAuditor.__index = SecurityAuditor

export type SecurityAuditorInstance = typeof(setmetatable({} :: {
	_client: any,
}, SecurityAuditor))

function SecurityAuditor.new(client: any): SecurityAuditorInstance
	return setmetatable({
		_client = client,
	}, SecurityAuditor)
end

-- Fast local static analysis without calling network
function SecurityAuditor.staticScan(code: string): Types.SecurityAuditResult
	local findings: { Types.SecurityFinding } = {}
	local lines = string.split(code, "\n")

	for lineIdx, line in ipairs(lines) do
		local lowerLine = string.lower(line)

		-- Rule 1: Deprecated wait() or spawn()
		if string.find(line, "%f[%a]wait%s*%(") and not string.find(line, "task%.wait") then
			table.insert(findings, {
				ruleId = "PERF_DEPRECATED_WAIT",
				severity = "Low",
				line = lineIdx,
				codeSnippet = line,
				description = "Using deprecated global `wait()` which throttles at 30Hz.",
				recommendation = "Replace with `task.wait()` for accurate 60Hz frame scheduling.",
			})
		end

		-- Rule 2: Deprecated spawn()
		if string.find(line, "%f[%a]spawn%s*%(") and not string.find(line, "task%.spawn") then
			table.insert(findings, {
				ruleId = "PERF_DEPRECATED_SPAWN",
				severity = "Low",
				line = lineIdx,
				codeSnippet = line,
				description = "Using deprecated global `spawn()` which introduces a 1-2 frame delay.",
				recommendation = "Replace with `task.spawn()` or `task.defer()`.",
			})
		end

		-- Rule 3: Client trusting remote event parameter
		if string.find(line, "OnServerEvent:Connect") then
			-- Check if parameters look dangerous
			if string.find(lowerLine, "damage") or string.find(lowerLine, "amount") or string.find(lowerLine, "cash") or string.find(lowerLine, "money") then
				table.insert(findings, {
					ruleId = "SEC_CLIENT_TRUST_PARAM",
					severity = "Critical",
					line = lineIdx,
					codeSnippet = line,
					description = "Potential exploit: RemoteEvent handler appears to receive client-sent damage/currency values.",
					recommendation = "Calculate damage and currency rewards strictly on the server. Never trust numbers sent from the client.",
				})
			end
		end

		-- Rule 4: DataStore without pcall
		if (string.find(line, ":GetAsync%(") or string.find(line, ":SetAsync%(") or string.find(line, ":UpdateAsync%(")) and not string.find(lowerLine, "pcall") then
			table.insert(findings, {
				ruleId = "SEC_DATASTORE_NO_PCALL",
				severity = "High",
				line = lineIdx,
				codeSnippet = line,
				description = "DataStore call without surrounding pcall. If Roblox servers encounter network hiccups, the script will crash.",
				recommendation = "Wrap all DataStore calls in `pcall()` and implement a retry loop with exponential backoff.",
			})
		end

		-- Rule 5: loadstring usage
		if string.find(line, "loadstring%s*%(") then
			table.insert(findings, {
				ruleId = "SEC_LOADSTRING_DANGER",
				severity = "Critical",
				line = lineIdx,
				codeSnippet = line,
				description = "Dynamic code execution via `loadstring` detected.",
				recommendation = "Avoid `loadstring`. It allows arbitrary code execution and backdoors if input is compromised.",
			})
		end
	end

	-- Calculate score
	local score = 100
	for _, f in ipairs(findings) do
		if f.severity == "Critical" then
			score = math.max(0, score - 35)
		elseif f.severity == "High" then
			score = math.max(0, score - 20)
		elseif f.severity == "Medium" then
			score = math.max(0, score - 10)
		else
			score = math.max(0, score - 5)
		end
	end

	return {
		score = score,
		totalIssues = #findings,
		findings = findings,
	}
end

-- Deep AI analysis with recommendations and patched code
function SecurityAuditor:deepAudit(code: string): (boolean, string)
	local prompt = `Please perform a deep exploit, vulnerability, and best-practice audit on the following Luau code:\n\n\`\`\`luau\n{code}\n\`\`\``
	return self._client:generate(prompt, PromptTemplates.SECURITY_AUDITOR_SYSTEM)
end

return SecurityAuditor
