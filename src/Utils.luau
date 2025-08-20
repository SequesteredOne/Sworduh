local Utils = {}

function Utils.isPlayer(target: Player | Model): boolean
    return target:IsA("Player")
end

function Utils.getCharacter(target: Player | Model): Model?
    if target:IsA("Player") then
        return target.Character
    else
        return target
    end
end

function Utils.getTeam(target: Player | Model): (Team | string)?
    if target:IsA("Player") then
        return (target :: Player).Team
    else
        local teamValue = (target :: Model):FindFirstChild("Team")
        return teamValue and teamValue.Value or nil
    end
end

return Utils