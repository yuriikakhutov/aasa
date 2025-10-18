local main = require("scripts.bot.main")

local start = os.clock()
local deadline = start + 60
while os.clock() < deadline do
    main.Think()
end
print("Smoke test completed")
