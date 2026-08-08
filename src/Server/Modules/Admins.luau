local ADMIN_USER_IDS = {
    [3439160531] = true,
}

local function Is_Admin(PlayerOrUserId: Player | number): boolean
    local UserId = if type(PlayerOrUserId) == "number" then PlayerOrUserId else PlayerOrUserId.UserId

    return ADMIN_USER_IDS[UserId] == true
end

return table.freeze({
    Is_Admin = Is_Admin,
})
