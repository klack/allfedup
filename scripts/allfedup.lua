-- AllFedUp: keeps a player's configured resource (default "food") full and optionally locked
-- while the player is lounging or in configured world prefixes. Debug logging available.

function init()
  self.cfg = root.assetJson("/allfedup.config") or {}
  self.enabled = self.cfg.enabled
  self.debugLog = self.cfg.debugLog
  self.wasFrozen = false
  self.foodlevel = 0
end

local function hasPrefix(s, p)
  -- Utility: check string prefix (nil-safe)
  return s and p and s:sub(1, #p) == p
end

local function isLounging()
  -- Returns true if the player is currently lounging (e.g. on a bed/seat)
  return player.loungingIn() ~= nil
end

local function playerInTargetWorld()
  -- Check current worldId against configured prefixes (useful for ship/world IDs)
  local wid = player.worldId()
  if not wid then return false end

  -- Prefix match (ship worlds)
  for _, p in ipairs(self.cfg.worldIdPrefixes or {}) do
    if hasPrefix(wid, p) then
      return true
    end
  end

  return false
end

local function logInfo(fmt, ...)
  -- Conditional logging helper to centralize debug checks
  if self.debugLog then sb.logInfo(fmt, ...) end
end

local function stateMessage(action)
  -- Build a consistent debug message including player and world context
  return string.format("[allfedup] %s for %s on %s, food=%s, lounging=%s",
    action, player.name(), tostring(player.worldId()), status.resource("food"), isLounging())
end

local function freezeFood(active)
  -- Apply or remove the reeze state based on 'active'
  if active and not self.wasFrozen then
    self.foodlevel = status.resource("food")
    self.wasFrozen = true
    logInfo(stateMessage("Activated"))
  end
  if active then
    if(self.foodlevel > status.resource("food")) then
      -- Freeze food level at stored value
      status.setResource("food", self.foodlevel)
    else
      -- Allow eating food
      self.foodlevel = status.resource("food")
    end
    status.setResourceLocked("food", true)
  else
    if self.wasFrozen then
      unfreezeFood()
    end
  end
end

function unfreezeFood()
  status.setResourceLocked("food", false)
  self.wasFrozen = false
  logInfo(stateMessage("Deactivated"))
end

function update(dt)
  -- Periodically determine whether feeze should be active
  if status.isResource("food") then
    freezeFood(playerInTargetWorld() or isLounging())
  end
end

function uninit()
  -- Ensure resource lock is released on script unload
  if self.wasFrozen then
    unfreezeFood()
  end
end
