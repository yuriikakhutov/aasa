local threat = require("core.threat")

return function()
    local hero = {
        position = Vector(0, 0, 0),
        attackRange = 600,
        maxHealth = 1500,
        health = 1200,
        mana = 600,
        maxMana = 800,
        recentDamage = 150,
    }
    local enemies = {
        {
            position = Vector(400, 0, 0),
            attackRange = 400,
            maxHealth = 1000,
            health = 600,
            mana = 400,
            maxMana = 600,
            recentDamage = 200,
            healthRatio = 0.6,
            hasDisable = true,
        }
    }
    local allies = {
        {
            position = Vector(-200, 0, 0),
            attackRange = 500,
            maxHealth = 1200,
            health = 900,
            mana = 300,
            maxMana = 500,
            recentDamage = 100,
        }
    }
    local score, winChance, safe = threat.evaluate(hero, allies, enemies)
    assert(score >= 0, "Threat score should be non-negative")
    assert(winChance >= 0 and winChance <= 1, "Win chance should be between 0 and 1")
    assert(type(safe) == "boolean", "Safe flag should be boolean")

    hero.attackDamage = 250
    hero.abilities = {}
    hero.items = {}
    local combo = threat.estimate_combo_damage(hero)
    assert(combo >= 250, "Combo damage should include base attack")

    local killProb = threat.kill_probability({ comboDamage = combo }, { health = 200 })
    assert(killProb > 0.5, "Kill probability should be high for low health targets")
    return true
end
