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

net.Receive("ShaderDamage", function()
    local dmg = net.ReadUInt(16)

    for id, eff in pairs(sd_effects) do
        local cvar = GetConVar("shaderdamage_ef_"..id)
        if not cvar then continue end
        if not cvar:GetBool() then continue end

        eff.func(eff.data or {}, eff.compoptions or {}, dmg)
    end
end)

sd_effects.radblur = {
    func = function(dat, ops, dmg)
        dat.life = 1

        if ops.scale_strength_with_damage:GetBool() then
            dat.strength = math.max(dat.strength, Lerp( dmg / ops.scalar_damage_max:GetInt(), 0, ops.max_strength:GetFloat() ) )
        else
            dat.strength = ops.max_strength:GetFloat()
        end

        if ctasks.radblur then return end
        AddCTask("radblur", function(dat, ops, dmg)
            hook.Add("RenderScreenspaceEffects", "sddmg_radblur", function()
                render.DrawMercRadialBlur( 0.5, 0.5, Lerp( math.ease.InSine(dat.life), 0, dat.strength ) )
            end)

            while dat.life > 0 do
                dat.life = math.max(dat.life - FrameTime() / ops.lifetime:GetFloat(), 0)
                coroutine.yield()
            end

            hook.Remove("RenderScreenspaceEffects", "sddmg_radblur")
            dat.strength = 0

            return true
        end, dat, ops, dmg)
    end,

    data = {
        strength = 0,
        life = 0
    },

    options = {
        lifetime = {1, 0.1, 5},
        max_strength = {0.5, 0.001, 1},
        scale_strength_with_damage = {0, 0, 1},
        scalar_damage_max = {100, 0, 16384}
    },

    nicename = "Radial Blur"
}

sd_effects.lowhpveins = {
    func = function(dat, ops)

        if ctasks.lowhpveins then return end
        if LocalPlayer():Health() / LocalPlayer():GetMaxHealth() > ops.health_threshold:GetFloat() then return end
        if not LocalPlayer():Alive() then return end
        AddCTask("lowhpveins", function(dat, ops)
            local mat = Material("shaderdamage/veinoverlay")
            local w, h = ScrW(), ScrH()
            local aspect = w / h

            local txh = h * 5
            local txw = txh * aspect

            local txsw = txw
            local txfw = h * aspect

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
            local fftaberr = 0
            local mtx = Matrix()
            mtx:SetTranslation(Vector(w * 0.5, h * 0.5, 0))

            hook.Add("RenderScreenspaceEffects", "sddmg_lowhpveins", function()
                surface.SetDrawColor(color_white)
                mat:SetFloat("$c0_x", 0.5 + math.Rand(-0.03, 0.03) )
                mat:SetFloat("$c0_y", 0.5 + math.Rand(-0.03, 0.03) )

                if snd and not isnumber(snd) and snd:GetState() == GMOD_CHANNEL_PLAYING then
                    snd:FFT(fftbl, FFT_256)
                    mat:SetFloat("$c0_z", Lerp(FrameTime() * 10, mat:GetFloat("$c0_z"), fftbl[5] * -5) )
                    fftaberr = Lerp(FrameTime() * 10, fftaberr, fftbl[5] * 10)
                end

                surface.SetMaterial(mat)
                cam.PushModelMatrix(mtx)
                surface.DrawTexturedRect(-txw * 0.5, -txh * 0.5, txw, txh)
                cam.PopModelMatrix()
                render.DrawMercChromaticAberration( fftaberr, true )
            end)

            WhileProg(function(p)
                txh = Lerp(math.ease.OutCubic(p), h * 5, h)
                txw = Lerp(math.ease.OutCubic(p), txsw, txfw)
            end, 0.5)

            while LocalPlayer():Alive() and LocalPlayer():Health() / LocalPlayer():GetMaxHealth() <= ops.health_threshold:GetFloat() do
                coroutine.yield()
            end

            snd:Stop()
            snd = nil

            WhileProg(function(p)
                txh = Lerp(math.ease.InSine(p), h, h * 5)
                txw = txh * aspect
            end, 0.2)

            hook.Remove("RenderScreenspaceEffects", "sddmg_lowhpveins")

            return true
        end, dat, ops)
    end,

    data = {},

    options = {
        health_threshold = {0.3, 0.01, 1}
    },

    nicename = "Low HP Veins Overlay"
}

sd_effects.chromatic_aberration = {
    func = function(dat, ops, dmg)
        dat.life = 1

        if ops.scale_strength_with_damage:GetBool() then
            dat.strength = math.max(dat.strength, Lerp( dmg / ops.scalar_damage_max:GetInt(), 0, ops.max_strength:GetFloat() ) )
        else
            dat.strength = ops.max_strength:GetFloat()
        end

        if ctasks.chromaberr then return end
        AddCTask("chromaberr", function(dat, ops, dmg)
            hook.Add("RenderScreenspaceEffects", "sddmg_chromatic_aberration", function()
                render.DrawMercChromaticAberration( Lerp( math.ease.InSine(dat.life), 0, dat.strength ), true )
            end)

            while dat.life > 0 do
                dat.life = math.max(dat.life - FrameTime() / ops.lifetime:GetFloat(), 0)
                coroutine.yield()
            end

            hook.Remove("RenderScreenspaceEffects", "sddmg_chromatic_aberration")
            dat.strength = 0

            return true
        end, dat, ops, dmg)
    end,

    data = {
        life = 0,
        strength = 0
    },

    options = {
        lifetime = {1, 0.1, 5},
        max_strength = {5, 0.001, 10},
        scale_strength_with_damage = {0, 0, 1},
        scalar_damage_max = {100, 0, 16384}
    },

    nicename = "Chromatic Aberration Radial"
}

sd_effects.highdmg_blur = {
    func = function(dat, ops, dmg)
        if dmg < ops.minimum_damage_threshold:GetInt() then return end

        dat.life = 1
        dat.strength = math.max(dat.strength, Lerp( dmg / ops.scalar_damage_max:GetInt(), 0, ops.max_strength:GetFloat() ) )

        if ctasks.highdmblur then return end
        AddCTask("highdmgblur", function(dat, ops, dmg)
            hook.Add("RenderScreenspaceEffects", "sddmg_highdmgblur", function()
                render.DrawMercBlur( Lerp( math.ease.InSine(dat.life), 0, dat.strength ) )
            end)

            while dat.life > 0 do
                dat.life = math.max(dat.life - FrameTime() / ops.lifetime:GetFloat(), 0)
                coroutine.yield()
            end

            hook.Remove("RenderScreenspaceEffects", "sddmg_highdmgblur")
            dat.strength = 0

            return true
        end, dat, ops, dmg)
    end,

    data = {
        life = 0,
        strength = 0
    },

    options = {
        lifetime = {1, 0.1, 10},
        max_strength = {1, 0.001, 3},
        minimum_damage_threshold = {50, 0, 1000},
        scalar_damage_max = {100, 0, 16384}
    },

    nicename = "High Damage Blur"
}

hook.Add( "AddToolMenuCategories", "ShaderDamage_SpawnCategory", function()
	spawnmenu.AddToolCategory( "Options", "ShaderDamage", "Shader Damage Options" )
end )

hook.Add( "PopulateToolMenu", "ShaderDamage_Settings", function()

    for id, v in pairs(sd_effects) do
        spawnmenu.AddToolMenuOption( "Options", "ShaderDamage", "EffectOptions"..id, v.nicename or id, "", "", function( panel )
            panel:ClearControls()
            panel:CheckBox("Enable", "shaderdamage_ef_"..id)

            if v.options then
                for opid, op in pairs(v.options) do
                    local explstr = string.Split(opid, "_")

                    for k, word in pairs(explstr) do
                        explstr[k] = string.gsub(word, "^%l", string.upper)
                    end

                    if op[2] == 0 and op[3] == 1 then
                        panel:CheckBox(table.concat(explstr, " "), "shaderdamage_ef_"..id.."_"..opid)
                    else
                        panel:NumSlider(table.concat(explstr, " "), "shaderdamage_ef_"..id.."_"..opid, op[2], op[3], 3)
                    end
                end
            end

        end )
    end

end )

for id, v in pairs(sd_effects) do
    CreateClientConVar("shaderdamage_ef_"..id, "1", true, false, "Shader Damage Effect Enable - "..id, 0, 1)

    if v.options then
        if not v.compoptions then
            v.compoptions = {}
        end

        for opid, op in pairs(v.options) do
            v.compoptions[opid] = CreateClientConVar("shaderdamage_ef_"..id.."_"..opid, op[1], true, false, "Shader Damage Effect Option - "..id, op[2], op[3])
        end
    end
end