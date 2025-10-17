local tests = {
    require("tests.test_selector"),
    require("tests.test_threat"),
    require("tests.test_scheduler"),
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
