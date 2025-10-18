local main = require("scripts.bot.main")
local ticks = 0
while ticks < 600 do
    main.Think()
    ticks = ticks + 1
end
print("Laning test executed")
