
Help = { }

dofile("stockgame.lua")
dofile("blog.lua")

function luabot:bot_roll(orig, dest, num)
  local s, e, ndice, sides = strfind(num or "", "(%d+)d(%d+)")
  local rolls = { }
  local strRolls = ""
  local total = 0

  for i=1,tonumber(ndice or 1) do
    rolls[i] = random(sides or 6)
    total = total + rolls[i]
    strRolls = strRolls .. tostring(rolls[i]) .. " "
  end

  return format("%s rolled %s, total %d", nick_from(orig), strRolls, total)
end

function rolldice(ndice, nsides)
  local total = 0

  for i=1,ndice do
    total = total + random(nsides or 6)
  end

  return total
end

function luabot:bot_rollcharacter(orig, dest)
  return format("%s:  STR %d  DEX %d  CON %d  WIS %d  INT %d  CHA %d", 
       nick_from(orig),
       rolldice(3,6), 
       rolldice(3,6), 
       rolldice(3,6), 
       rolldice(3,6), 
       rolldice(3,6), 
       rolldice(3,6))
end

function luabot:bot_power(orig, dest, val, channel)
  local d = channel or dest

  if not channel and dest == self.botnick then
    return "Main power switch permanently on."
  else
    if val == "on" or val == "up" then
      self.activeDests[d] = val
    elseif val == "off" or val == "down" then
      self.activeDests[d] = nil
    end
  end

  return format("powered %s for '%s'", self.activeDests[d] or "off", d)
end

function luabot:bot_nick(orig, dest, newnick)
  irc_send(format("nick :%s", newnick))
end

function luabot:bot_join(orig, dest, chan)
  irc_send(format("join :%s", chan))
end

function luabot:bot_rehash(orig, dest)
   dofile("bot_cmd.lua")
   return "Reloaded lua source."
end

function luabot:bot_ver(orig, dest)
   return format("yulbot v1.0, using nick '%s'", self.botnick)
end

function luabot:bot_seterror(orig, dest, newdest)
   self.errordest = newdest
   return format("error destination set to '%s'", self.errordest or "none")
end

function luabot:bot_leave(orig, dest, chan)
  irc_send(format("PART %s", chan or dest))
end

function luabot:bot_op(orig, dest, user, chan)
  irc_send(format("MODE %s +o %s", chan or dest, user or nick_from(orig)))
end

