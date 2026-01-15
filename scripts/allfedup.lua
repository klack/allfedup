-- AllFedUp: keeps a player's configured resource (default "food") full and optionally locked
-- while the player is lounging or in configured world prefixes. Debug logging available.

function init()
  self.cfg = root.assetJson("/allfedup.config") or {}
  -- defaults
  self.enabled = (self.cfg.enabled ~= false)
  self.debugLog = self.cfg.debugLog
  self.resource = self.cfg.resource or "food"
  self.worldPrefixes = self.cfg.worldIdPrefixes or {}
  self.wasFrozen = false
  self.resourceLevel = 0
end

local function hasPrefix(s, p)
  -- Utility: check string prefix (nil-safe)
  return s and p and s:sub(1, #p) == p
end

local function getName()
  -- Vanilla clients do not have player.name(); fall back to uniqueId()
  if player.name then 
    return player.name()
  end
  
  return player.uniqueId()
end

local function playerInTargetWorld()
  -- Check current worldId against configured prefixes (useful for ship/world IDs)
  local wid = player.worldId()
  if not wid then return false end

  -- Prefix match (ship worlds)
  for _, p in ipairs(self.worldPrefixes) do
    if hasPrefix(wid, p) then return true end
  end

  return false
end

local function logInfo(fmt, ...)
  -- Conditional logging helper to centralize debug checks
  if self.debugLog then sb.logInfo(fmt, ...) end
end

local function stateMessage(action)
  -- Build a consistent debug message including player and world context
  return string.format("[allfedup] %s for %s on %s, %s=%s, lounging=%s",
    action, getName(), tostring(player.worldId()), self.resource, tostring(status.resource(self.resource)), tostring(player.isLounging()))
end

local function unfreezeResource()
  status.setResourceLocked(self.resource, false)
  self.wasFrozen = false
  logInfo(stateMessage("Deactivated"))
end

-- Localized freeze/unfreeze for the configured resource
local function freezeResource(active)
  -- Apply or remove the freeze state based on 'active'
  if active and not self.wasFrozen then
    self.resourceLevel = status.resource(self.resource)
    self.wasFrozen = true
    logInfo(stateMessage("Activated"))
  end
  if active then
    if self.resourceLevel > status.resource(self.resource) then
      -- Freeze resource level at stored value
      status.setResource(self.resource, self.resourceLevel)
    else
      -- Allow consumption
      self.resourceLevel = status.resource(self.resource)
    end
    status.setResourceLocked(self.resource, true)
  else
    if self.wasFrozen then unfreezeResource() end
  end
end

function update(dt)
  -- Periodically determine whether freeze should be active
  if not self.enabled then return end
  if status.isResource(self.resource) then
    freezeResource(playerInTargetWorld() or isLounging())
  end
end

function uninit()
  -- Ensure resource lock is released on script unload
  if self.wasFrozen then
    unfreezeResource()
  end
end
