function init()
  self.cfg = root.assetJson("/allfedup.config") or {}
  self.resourceName = self.cfg.resourceName or "food"
  self.keepFull = (self.cfg.keepFull ~= false)
  self.lockConsumption = (self.cfg.lockConsumption ~= false)
  self.debugLog = (self.cfg.debugLog == true)
  self.wasActive = false
end

local function hasPrefix(s, p)
  return s and p and s:sub(1, #p) == p
end

local function isLounging()
  return player.loungingIn() ~= nil
end

local function playerInTargetWorld()
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
  if self.debugLog then sb.logInfo(fmt, ...) end
end

local function stateMessage(action)
  return string.format("[allfedup] %s for %s on %s, lounging=%s",
    action, tostring(player.name()), tostring(player.worldId()), tostring(isLounging()))
end

local function applyActive(active)
  if active then
    -- Some hunger drains use consumeResource (blocked by lock),
    -- others modify/set the resource directly. Keeping it full is the robust approach.
    if self.keepFull and status.isResource(self.resourceName) then
      status.setResourcePercentage(self.resourceName, 1.0)
    end
    if self.lockConsumption then
      status.setResourceLocked(self.resourceName, true)
    end
    if not self.wasActive then
      self.wasActive = true
      logInfo(stateMessage("Activated"))
    end
  else
    if self.wasActive then
      if self.lockConsumption then
        status.setResourceLocked(self.resourceName, false)
      end
      logInfo(stateMessage("Deactivated"))
      self.wasActive = false
    end
  end
end

function update(dt)
  local active = playerInTargetWorld() or isLounging()
  applyActive(active)
end

function uninit()
  if self.lockConsumption then
    status.setResourceLocked(self.resourceName, false)
    if self.wasActive and self.debugLog then
      sb.logInfo("[allfedup] Deactivated for %s on %s, lounging=%s",
        tostring(player.name()), tostring(player.worldId()), tostring(isLounging()))
    end
    self.wasActive = false
  end
end
