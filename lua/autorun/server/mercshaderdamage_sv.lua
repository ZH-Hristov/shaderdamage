util.AddNetworkString("ShaderDamage")

hook.Add("PostEntityTakeDamage", "ShaderDamage_DamageHook", function(ent, dmg, took)
    if not ent:IsPlayer() then return end
    if not took then return end
    net.Start("ShaderDamage")
    net.WriteUInt(math.Round(dmg:GetDamage()), 16)
    net.Send(ent)
end)