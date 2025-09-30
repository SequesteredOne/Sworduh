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
    end

    local teamValue = (target :: Model):FindFirstChild("Team")
    if teamValue and teamValue:IsA("StringValue") then
        return teamValue.Value
    end

    return nil
end

return Utils