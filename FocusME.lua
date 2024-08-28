-- Define the action bar slot for Intervene
local TAUNT_ACTION_SLOT = 36

local function getSpellId(targetSpellName, targetSpellRank)
    for i = 1, 200 do
        local spellName, spellRank = GetSpellName(i, "spell")
        if spellName == targetSpellName then
            if not targetSpellRank or (spellRank == targetSpellRank) then
                return i
            end
        end
    end
    return nil
end

local function GetCooldown(spellId)
    if not spellId then
        return 10 -- Default to 10 seconds if no spellId is provided
    end

    local start, duration, enabled = GetSpellCooldown(spellId, "spell")

    -- Check if the spell is on global cooldown
    if duration > 0 and duration <= 1.5 then
        duration = 1.5 -- Set duration to GCD (1.5 seconds)
    end

    if duration == 0 then
        return 0 -- Spell is ready
    end

    return start + duration - GetTime()
end


-- Function to check if Challenging Shout is in duel range (9.9 yards)
local function IsChallengingShoutInRange()
    return CheckInteractDistance("target", 3) -- 9.9 yards range for duel
end

local function FocusMeNow(mode)
    -- Function to get cooldown
    local tauntCooldown = GetCooldown(getSpellId("Taunt"))
    local mockingBlowCooldown = GetCooldown(getSpellId("Mocking Blow"))
	local chargeCooldown = GetCooldown(getSpellId("Charge"))

    -- Helper function to check if a specific stance is active
    local function IsInStance(index)
        local _, _, active, _ = GetShapeshiftFormInfo(index)
        return active == 1
    end

    -- Change stance with cooldown consideration
    local function ChangeStance(index)
        if not IsInStance(index) then
            if index == 1 then
                CastSpellByName("Battle Stance")
            elseif index == 2 then
                CastSpellByName("Defensive Stance")
            elseif index == 3 then
                CastSpellByName("Berserker Stance")
            end
            return true -- Indicates stance change was initiated
        end
        return false -- Already in the correct stance
    end

    -- Check if the target meets the conditions
    local function ShouldExecute()
        if not UnitExists("target") then
            return false -- No target selected
        end

        if UnitIsFriend("player", "target") then
            return false -- Target is friendly
        end

        if not UnitExists("targettarget") then
            return false -- Target has no target
        end

        return true -- Target meets all conditions
    end

    -- Determine if Intervene is needed (when Taunt is out of range)
    local needsIntervene = IsActionInRange(TAUNT_ACTION_SLOT) ~= 1

    if ShouldExecute() then
        -- If Intervene is needed but the player is not in combat
        if needsIntervene and not UnitAffectingCombat("player") and chargeCooldown == 0 then
            -- Switch to Battle Stance if not already in it
            if ChangeStance(1) then return end -- Battle Stance
            
            -- Cast Charge on the target
            CastSpellByName("Charge")
            
            -- After Charge and stance change, proceed with the usual Intervene logic
            if not UnitIsUnit("targettarget", "player") then
                if tauntCooldown == 0 then
					-- Ensure we are in Defensive Stance after Charge and before Taunt
					if not IsInStance(2) then
						ChangeStance(2) -- Switch to Defensive Stance
					end
                    CastSpellByName("Taunt")
                elseif mockingBlowCooldown == 0 then
                    if not IsInStance(1) then
                        ChangeStance(1) -- Switch to Battle Stance for Mocking Blow
                    end
                    if UnitMana("player") < 10 then
                        CastSpellByName("Bloodrage")
                    end
                    CastSpellByName("Mocking Blow")
                elseif IsChallengingShoutInRange() then -- Only cast if within range
                    CastSpellByName("Challenging Shout")
                end
            end
        else
            -- Existing Intervene logic for when player is already in combat
            if needsIntervene then
                if not IsInStance(2) then
                    ChangeStance(2) -- Switch to Defensive Stance
                end

                if UnitMana("player") < 10 then
                    CastSpellByName("Bloodrage")
                end

                if UnitExists("targettarget") then
                    TargetUnit("targettarget")
                    CastSpellByName("Intervene")
                    TargetLastTarget()
                end

                -- After Intervene, recheck if the target is still targeting the player
                if not UnitIsUnit("targettarget", "player") then
                    if tauntCooldown == 0 then
                        CastSpellByName("Taunt")
                    elseif mockingBlowCooldown == 0 then
                        if not IsInStance(1) then
                            ChangeStance(1) -- Switch to Battle Stance for Mocking Blow
                        end
                        if UnitMana("player") < 10 then
                            CastSpellByName("Bloodrage")
                        end
                        CastSpellByName("Mocking Blow")
                    elseif IsChallengingShoutInRange() then -- Only cast if within range
                        CastSpellByName("Challenging Shout")
                    end
                end
            else
                -- Existing logic when Intervene is not needed
                if not UnitIsUnit("targettarget", "player") then
                    if tauntCooldown == 0 then
                        if ChangeStance(2) then return end -- Defensive Stance
                        CastSpellByName("Taunt")
                    elseif mockingBlowCooldown == 0 then
                        if ChangeStance(1) then return end -- Battle Stance
                        if UnitMana("player") < 10 then
                            CastSpellByName("Bloodrage")
                        end
                        CastSpellByName("Mocking Blow")
                    elseif IsChallengingShoutInRange() then -- Only cast if within range
                        CastSpellByName("Challenging Shout")
                    end
                end
            end
        end

        -- Defensive Mode: Check if target's target is the player and switch to Defensive Stance
        if mode == "defensive" and UnitIsUnit("targettarget", "player") and not IsInStance(2) then
            ChangeStance(2) -- Defensive Stance
            return -- End function after entering Defensive Stance
        end

        -- Berserk Mode: Check if target's target is the player and switch to Berserker Stance
        if mode == "berserk" and UnitIsUnit("targettarget", "player") then
            ChangeStance(3) -- Berserker Stance
            return -- End function after entering Berserker Stance
        end
    end
end


-- Register the slash command for FocusMe
SLASH_FOCUSME1 = "/focusme"
SLASH_FOCUSMEBERSERK1 = "/focusmeberserk"
SLASH_FOCUSMEDEFENSIVE1 = "/focusmedefensive"

SlashCmdList["FOCUSME"] = function(msg)
    FocusMeNow(nil)
end

SlashCmdList["FOCUSMEBERSERK"] = function(msg)
    FocusMeNow("berserk")
end

SlashCmdList["FOCUSMEDEFENSIVE"] = function(msg)
    FocusMeNow("defensive")
end