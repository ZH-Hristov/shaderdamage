local ctasks = {}
local sd_effects = {}

local function AddCTask(id, func, datatable, opstable)
    if table.IsEmpty(ctasks) then
        hook.Add("Think", "shaderdamage_coroutines", function()
            for id, couro in pairs(ctasks) do
                if couro[1](couro[2], couro[3]) then
                    ctasks[id] = nil
                end
            end
        end)
    end

    ctasks[id] = {coroutine.wrap(func), datatable, opstable}
end

local function RemoveCTask(id)
    ctasks[id] = nil

    if table.IsEmpty(ctasks) then
        hook.Remove("Think", "shaderdamage_coroutines")
    end
end

local function WhileProg(func, time)
    local prog = 0

    while prog < 1 do
        prog = math.min(prog + FrameTime() / time, 1)
        func(prog)
        coroutine.yield()
    end
end

gameevent.Listen( "player_hurt" )

hook.Add( "player_hurt", "shader_damage_player_hurt", function( data ) 
    local ply = Player(data.userid)
    if ply ~= LocalPlayer() then return end
    for id, eff in pairs(sd_effects) do
        local cvar = GetConVar("shaderdamage_ef_"..id)
        if not cvar then continue end
        if not cvar:GetBool() then continue end

        eff.func(eff.data or {}, eff.options or {})
    end
end )

sd_effects.radblur = {
    func = function(dat, ops)
        dat.life = 1

        if ctasks.radblur then return end
        AddCTask("radblur", function(dat, ops)
            hook.Add("RenderScreenspaceEffects", "sddmg_radblur", function()
                render.DrawMercRadialBlur( 0.5, 0.5, Lerp(math.ease.InSine(dat.life), 0, ops.maxstrength:GetFloat()) )
            end)

            while dat.life > 0 do
                dat.life = math.max(dat.life - FrameTime() / ops.lifetime:GetFloat(), 0)
                coroutine.yield()
            end

            hook.Remove("RenderScreenspaceEffects", "sddmg_radblur")

            return true
        end, dat, ops)
    end,

    data = {
        life = 0
    },

    options = {
        lifetime = {1, 0.1, 5},
        maxstrength = {5, 0.001, 10}
    }
}

sd_effects.lowhpveins = {
    func = function(dat, ops)

        if ctasks.lowhpveins then return end
        if LocalPlayer():Health() / LocalPlayer():GetMaxHealth() > ops.hpthreshold:GetFloat() then return end
        AddCTask("lowhpveins", function(dat, ops)
            local mat = Material("shaderdamage/veinoverlay")
            local w, h = ScrW(), ScrH()
            local aspect = w / h

            local txh = h * 5
            local txw = txh * aspect

            local x = -txw * 0.5
            local y = -txh * 0.5

            local snd

            sound.PlayFile("sound/player/heartbeat1.wav", "noplay noblock", function(bassy)
                if bassy then
                    snd = bassy
                else
                    snd = 0
                end
            end)

            while not snd do coroutine.yield() end
            snd:EnableLooping(true)
            snd:Play()

            local fftbl = {}
            hook.Add("RenderScreenspaceEffects", "sddmg_lowhpveins", function()
                surface.SetDrawColor(color_white)
                mat:SetFloat("$c0_x", 0.5 + math.Rand(-0.03, 0.03) )
                mat:SetFloat("$c0_y", 0.5 + math.Rand(-0.03, 0.03) )

                if snd and not isnumber(snd) and snd:GetState() == GMOD_CHANNEL_PLAYING then
                    snd:FFT(fftbl, FFT_256)
                    mat:SetFloat("$c0_z", Lerp(FrameTime() * 10, mat:GetFloat("$c0_z"), fftbl[5] * -5) )
                end

                surface.SetMaterial(mat)
                surface.DrawTexturedRect(x, y, txw, txh)
            end)

            WhileProg(function(p)
                txh = Lerp(math.ease.OutSine(p), h * 5, h)
                txw = txh * aspect

                x = Lerp(math.ease.OutSine(p), -txw * 0.5, 0)
                y = Lerp(math.ease.OutSine(p), -txh * 0.5, 0)
            end, 1)

            while LocalPlayer():Health() / LocalPlayer():GetMaxHealth() <= ops.hpthreshold:GetFloat() do
                coroutine.yield()
            end

            snd:Stop()
            snd = nil

            WhileProg(function(p)
                txh = Lerp(math.ease.InSine(p), h, h * 5)
                txw = txh * aspect

                x = Lerp(math.ease.InSine(p), 0, -txw * 0.5)
                y = Lerp(math.ease.InSine(p), 0, -txh * 0.5)
            end, 0.4)

            hook.Remove("RenderScreenspaceEffects", "sddmg_lowhpveins")

            return true
        end, dat, ops)
    end,

    data = {},

    options = {
        hpthreshold = {0.3, 0.01, 1}
    }
}

for id, v in pairs(sd_effects) do
    CreateClientConVar("shaderdamage_ef_"..id, "0", true, false, "Shader Damage Effect Enable - "..id, 0, 1)

    if v.options then
        for opid, op in pairs(v.options) do
            v.options[opid] = CreateClientConVar("shaderdamage_ef_"..id.."_"..opid, op[1], true, false, "Shader Damage Effect Option - "..id, op[2], op[3])
        end
    end
end