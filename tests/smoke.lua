local Bot = require('scripts.bot.main')

Bot.Init()

for i = 1, 600 do
    Bot.Tick()
end

print('[SMOKE] Completed 600 ticks without errors')
