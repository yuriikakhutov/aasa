if not _G.Vector then
    function _G.Vector(x, y, z)
        return { x = x or 0, y = y or 0, z = z or 0 }
    end
end

local tests = {
    require("tests.test_selector"),
    require("tests.test_threat"),
    require("tests.test_scheduler"),
    require("tests.test_economy"),
    require("tests.test_nav"),
}

return function()
    local results = {}
    for index, test in ipairs(tests) do
        local ok, res = pcall(test)
        if not ok then
            results[index] = { success = false, error = res }
        else
            results[index] = { success = true }
        end
    end
    return results
end
