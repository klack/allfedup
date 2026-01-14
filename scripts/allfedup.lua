-- AllFedUp: keeps a player's configured resource (default "food") full and optionally locked
-- while the player is lounging or in configured world prefixes. Debug logging available.

function init()
  -- Load configuration and derive behavior flags
  self.cfg = root.assetJson("/allfedup.config") or {}
  -- Name of the resource to protect (e.g. "food")
  self.resourceName = self.cfg.resourceName or "food"
  -- keepFull: if true, constantly set resource to 100%
  self.keepFull = (self.cfg.keepFull ~= false)
  -- lockConsumption: if true, lock the resource to block consumeResource
  self.lockConsumption = (self.cfg.lockConsumption ~= false)
  -- debugLog: when true, emit sb.logInfo messages
  self.debugLog = (self.cfg.debugLog ~= true)
  -- Tracks whether the effect was active previously
  self.wasActive = false
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
  return string.format("[allfedup] %s for %s on %s, lounging=%s",
    action, tostring(player.name()), tostring(player.worldId()), tostring(isLounging()))
end

local function applyActive(active)
  -- Apply or remove the protection state based on 'active'
  if active then
    -- Some hunger drains use consumeResource (blocked by lock),
    -- others modify/set the resource directly. Keeping it full is the robust approach.
    if self.keepFull and status.isResource(self.resourceName) then
      -- Ensure the resource is at 100%
      status.setResourcePercentage(self.resourceName, 1.0)
    end
    if self.lockConsumption then
      -- Lock the resource to prevent consumption via consumeResource
      status.setResourceLocked(self.resourceName, true)
    end
    if not self.wasActive then
      self.wasActive = true
      logInfo(stateMessage("Activated"))
    end
  else
    if self.wasActive then
      if self.lockConsumption then
        -- Unlock the resource when deactivating
        status.setResourceLocked(self.resourceName, false)
      end
      logInfo(stateMessage("Deactivated"))
      self.wasActive = false
    end
  end
end

function update(dt)
  -- Periodically determine whether protection should be active and apply it
  local active = playerInTargetWorld() or isLounging()
  applyActive(active)
end

function uninit()
  -- Ensure resource lock is released on script unload
  if self.lockConsumption then
    status.setResourceLocked(self.resourceName, false)
    if self.wasActive and self.debugLog then
      sb.logInfo("[allfedup] Deactivated for %s on %s, lounging=%s",
        tostring(player.name()), tostring(player.worldId()), tostring(isLounging()))
    end
    self.wasActive = false
  end
end
