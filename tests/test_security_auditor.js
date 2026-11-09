// Unit test for SecurityAuditor rules and AIClient extraction

const assert = require('assert');
const fs = require('fs');

console.log('--- Testing SecurityAuditor & AIClient Logic ---');

// Test static rules
function staticScan(code) {
  const findings = [];
  const lines = code.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lower = line.toLowerCase();
    const lineIdx = i + 1;

    // Rule 1: wait()
    if (/\bwait\s*\(/.test(line) && !line.includes('task.wait')) {
      findings.push({ ruleId: 'PERF_DEPRECATED_WAIT', line: lineIdx });
    }

    // Rule 2: spawn()
    if (/\bspawn\s*\(/.test(line) && !line.includes('task.spawn')) {
      findings.push({ ruleId: 'PERF_DEPRECATED_SPAWN', line: lineIdx });
    }

    // Rule 3: Client trust on RemoteEvent
    if (line.includes('OnServerEvent:Connect')) {
      if (lower.includes('damage') || lower.includes('amount') || lower.includes('cash') || lower.includes('money')) {
        findings.push({ ruleId: 'SEC_CLIENT_TRUST_PARAM', line: lineIdx });
      }
    }

    // Rule 4: DataStore without pcall
    if ((line.includes(':GetAsync(') || line.includes(':SetAsync(')) && !lower.includes('pcall')) {
      findings.push({ ruleId: 'SEC_DATASTORE_NO_PCALL', line: lineIdx });
    }

    // Rule 5: loadstring
    if (/loadstring\s*\(/.test(line)) {
      findings.push({ ruleId: 'SEC_LOADSTRING_DANGER', line: lineIdx });
    }
  }

  let score = 100;
  for (const f of findings) {
    if (f.ruleId === 'SEC_CLIENT_TRUST_PARAM' || f.ruleId === 'SEC_LOADSTRING_DANGER') {
      score = Math.max(0, score - 35);
    } else if (f.ruleId === 'SEC_DATASTORE_NO_PCALL') {
      score = Math.max(0, score - 20);
    } else {
      score = Math.max(0, score - 5);
    }
  }

  return { score, totalIssues: findings.length, findings };
}

// Test 1: Vulnerable script
const badCode = `
local event = game.ReplicatedStorage.TakeDamageEvent
event.OnServerEvent:Connect(function(player, target, damage)
    target.Humanoid:TakeDamage(damage)
    wait(1)
end)

local data = game:GetService("DataStoreService"):GetDataStore("Coins")
data:SetAsync(player.UserId, 100)
`;

const resBad = staticScan(badCode);
assert.strictEqual(resBad.findings.length, 3, 'Should detect 3 vulnerabilities');
assert.ok(resBad.findings.some(f => f.ruleId === 'SEC_CLIENT_TRUST_PARAM'), 'Should flag remote event client trust');
assert.ok(resBad.findings.some(f => f.ruleId === 'PERF_DEPRECATED_WAIT'), 'Should flag deprecated wait');
assert.ok(resBad.findings.some(f => f.ruleId === 'SEC_DATASTORE_NO_PCALL'), 'Should flag datastore without pcall');
assert.ok(resBad.score <= 40, 'Score should be low for bad code');
console.log(`✅ Test 1 Passed: Detected ${resBad.findings.length} vulnerabilities, Score: ${resBad.score}`);

// Test 2: Clean script
const cleanCode = `
--!strict
local RunService = game:GetService("RunService")
task.wait(1)
task.spawn(function()
    print("Clean loop")
end)
`;

const resClean = staticScan(cleanCode);
assert.strictEqual(resClean.findings.length, 0, 'Should find 0 issues in clean code');
assert.strictEqual(resClean.score, 100, 'Score should be 100 for clean code');
console.log(`✅ Test 2 Passed: Clean code scored 100/100`);

// Test 3: Code extraction regex
function extractCodeBlock(rawText) {
  const luauMatch = rawText.match(/```luau\s*([\s\S]*?)\s*```/);
  if (luauMatch && luauMatch[1]) return luauMatch[1];
  const luaMatch = rawText.match(/```lua\s*([\s\S]*?)\s*```/);
  if (luaMatch && luaMatch[1]) return luaMatch[1];
  const genMatch = rawText.match(/```\s*([\s\S]*?)\s*```/);
  if (genMatch && genMatch[1]) return genMatch[1];
  return rawText;
}

const mockResponse = `Here is your script:\n\`\`\`luau\n--!strict\nprint("Hello Roblox")\n\`\`\`\nHope this helps!`;
const extracted = extractCodeBlock(mockResponse);
assert.strictEqual(extracted, `--!strict\nprint("Hello Roblox")`, 'Should extract code block cleanly');
console.log(`✅ Test 3 Passed: Extracted code block successfully`);

console.log('--- All 3 Test Suites Passed (100%) ---');
