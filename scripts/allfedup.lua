function init()
  self.cfg = root.assetJson("/allfedup.config") or {}
  self.worldIds = {}
  for _, wid in ipairs(self.cfg.worldIds or {}) do
    self.worldIds[wid] = true
  end
  self.resourceName = self.cfg.resourceName or "food"
  self.keepFull = (self.cfg.keepFull ~= false)
  self.lockConsumption = (self.cfg.lockConsumption ~= false)
  self.debugLog = (self.cfg.debugLog == true)
  self.wasActive = false
end

local function hasPrefix(s, p)
  return s and p and s:sub(1, #p) == p
end

local function playerInTargetWorld(cfg)
  local wid = player.worldId()
  if not wid then return false end

  -- Prefix match (ship worlds)
  for _, p in ipairs(cfg.worldIdPrefixes or {}) do
    if hasPrefix(wid, p) then
      return true
    end
  end

  return false
end

local function isLounging()
  return player.loungingIn() ~= nil
end

function update(dt)
  local wid = player.worldId()
  local active = playerInTargetWorld(self.cfg) or isLounging()

  if active then
    -- Some hunger drains use consumeResource (blocked by lock),
    -- others modify/set the resource directly. Keeping it full is the robust approach.
    if self.keepFull and status.isResource(self.resourceName) then
      status.setResourcePercentage(self.resourceName, 1.0)
    end
    if self.lockConsumption then
      status.setResourceLocked(self.resourceName, true)
    end
    if self.wasActive == false then
      self.wasActive = true
      if self.debugLog then
        sb.logInfo("[allfedup] Activated for %s on %s", tostring(player.name()), tostring(wid))
      end
    end
  else
    if self.wasActive then
      if self.lockConsumption then
        status.setResourceLocked(self.resourceName, false)
        if self.debugLog then
          sb.logInfo("[allfedup] Not active for %s on %s", tostring(player.name()), tostring(wid))
        end        
      end
      self.wasActive = false
    end
  end
end

function uninit()
  if self.lockConsumption then
    status.setResourceLocked(self.resourceName, false)
    if self.wasActive and self.debugLog then
      local wid = player.worldId()
      sb.logInfo("[allfedup] Deactivated for %s on %s", tostring(player.name()), tostring(wid))
    end        
  end
end
