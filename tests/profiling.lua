local Validators = require('scripts.bot.core.validators')

Validators.assert_no_globals()

local stats = Validators.assert_code_volume('./scripts', 300)
assert(stats.code >= 300, 'code volume too low for test expectations')

local history = {
    { kind = 'move', time = 0 },
    { kind = 'move', time = 0.2, signature = 'next' },
}
Validators.assert_no_spam_orders(history)

local safePath = { waypoints = { { x = 1000, y = 1000 } } }
local towers = { { tier = 4, pos = { x = 0, y = 0 }, radius = 700 } }
local ok = pcall(Validators.assert_pathing_safety, safePath, towers)
assert(ok, 'safe path should pass')

local violation = { waypoints = { { x = 10, y = 10 } } }
ok = pcall(Validators.assert_pathing_safety, violation, towers)
assert(ok == false, 'dangerous path should raise error')

ok = pcall(Validators.assert_abilities_no_passives, { { name = 'test', isPassive = true } })
assert(ok == false, 'passive detection expected')

ok = pcall(Validators.assert_rubick_no_blink_misuse, {
    { usedBlink = true, safeCastRange = 1200, blinkRange = 800 },
})
assert(ok == false, 'blink misuse should be flagged')

print(string.format('[PROFILING] code=%d comment=%d blank=%d', stats.code, stats.comment, stats.blank))
