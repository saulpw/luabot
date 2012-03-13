
luabot = luabot or { 
  activeDests = { },
  botnick = "luabot"
}

dofile("helpers.lua")
dofile("bot_cmd.lua")

settag(luabot.activeDests, uppercaseIndexTag)

function luabot:unknown(orig, cmd, ...)
  log (format("*** (%d) %s: %s", getn(arg), cmd, collateparms(arg) or ""))

if nil then
  local dest = arg[2]
  -- cheap hack to get around the fact that i sometimes don't know my name
  -- hopefully we can assume that the server does (and would not lie to me)
  if self.botnick ~= dest then
     bot_error(format("my nick was '%s', server says...'%s'", self.botnick, dest))
     self.botnick = dest
  end
end
end

function luabot:do_bot_cmd(orig, dest, botcmd, parmtable)
   local cmdfunc = self[strlower("bot_"..botcmd)]
   local replystr = nil

   if not self.activeDests[dest] and self.botnick ~= dest then
     return        -- powered down for this channel
   end

   log(format("%s asked '%s' to '%s %s'", orig, dest, botcmd, 
      collateparms(arg) or ""))

   if type(cmdfunc) == "function" then
     local cmdargs = { self, orig, dest }
     foreachi(parmtable, function (i,v) tinsert(%cmdargs, v) end)
     replystr  = call(cmdfunc, cmdargs, "", bot_error)
   else
--     replystr = format("'%s' is not a valid bot command", botcmd)
   end

   if type(replystr) == "string" then 
     local tonick = dest
     if dest == self.botnick then
       tonick = nick_from(orig)
     end

--     log("Response: "..replystr)
     irc_send(format("notice %s :%s", tonick, replystr))
   end
end

function bot_error(err)
   local errdest = luabot.errordest
   if errdest then
     local errstr = format("notice %s : error: %s", errdest, err)
     irc_send(errstr)
   end
   log("Error: "..err)
end

function luabot:KICK(orig, channel, user, reason)
   log(format("%s KICK %s %s (%s)", orig, channel, user, reason))
end

function luabot:PING(orig, pinger)
   irc_send(format("pong :%s", pinger))
end

function luabot:NICK(orig, newnick)
   log(format("%s NICK %s", orig, newnick))

   if self:is_me(orig) then
     self.botnick = newnick
   end
end

function luabot:ERROR(orig, err)
  bot_error(err)
  log (format("ERROR: (%s) '%s'", orig or "", err or ""))
end

function luabot:QUIT(orig, reason)
   log(format("%s QUIT (%s)", orig, reason or ""))

   if self:is_me(orig) then
      reconnect()
      log("reconnecting...")
   end
end

function luabot:KILL(orig, user, reason)
   log(format("%s KILL %s (%s)", orig, user, reason))

   if self.botnick == user then
      reconnect()
      log("reconnecting...")
   end
end

function luabot:PART(orig, channel)
   log (format("%s left channel %s", orig, channel))
end

function luabot:PRIVMSG(orig, user, msg)
   local nick, email = nick_from(orig)
   local parms = { }

   log (format("<%9s:%s> %s", nick, user, msg or ""))

   local s, e, cmd, rest = strfind(msg, "%%(%S+)(.*)")
   if cmd then
      gsub(rest, "(%S+)", function (v) tinsert(%parms, v) end)
   elseif user == self.botnick then
      local resp = chat_ask(nick, msg)

      return resp
   end

--   log(format("request to %s (parms '%s')", cmd or "UNKNOWN", collateparms(parms) or ""))

   if cmd then
      self:do_bot_cmd(orig, user, cmd, parms)
   end
end

function luabot:NOTICE(orig, dest, msg)
   local nick, email = nick_from(orig)

   log (format("-%9s:%s- %s", nick, dest, msg or ""))
end

function luabot:JOIN(orig, channel)
   log(format("%s joined channel %s", orig, channel))
end

function luabot:MODE(orig, channel, parms, names)
   log(format("%s MODE %s %s %s", orig or "NONE", channel, parms, names or ""))
end

function luabot:TOPIC(orig, channel, top)
   local nick, email = nick_from(orig)
   log(format("%s changed the topic on channel %s to '%s'", 
     nick, channel, top))
end

function luabot:INVITE(orig, user, channel)
   local nick, email = nick_from(orig)

   log(format("%s invited %s to %s.  i'm going.", 
     nick, user, channel))

   self.activeDests[channel] = "on"

   irc_send(format("join :%s", channel))
end

function luabot:is_me(orig)
   local old_nick, old_email = nick_from(orig)

   if old_nick == self.botnick then
      return 1
   else 
      return nil
   end
end

function collateparms(arg)
  local msg = ""

  if type(arg) ~= "table" then return msg end

  for i,v in arg do
    if type(v) == "string" then
      msg = msg .. " " .. v
    end
  end
   
  return msg
end

function nick_from(orig)
--   local s, e, nick, email = strfind(orig, ":([^!: \n\r]*)!([^: \n\r]*)?")
   local s, e, nick = "*unknown*"

   if orig then
     s, e, nick, email = strfind(orig, "([^! ]*)!([^ ]*)")
   end

   return nick or "", email
end


