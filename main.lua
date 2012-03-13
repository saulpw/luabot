log = print

dofile("raw_irc.lua")

function init(nick, userid, fullname, server, port)
  local s = server or "irc.catch22.org"
  local p = port or 6667

  g_botnick = nick or "luabot"
  g_botuserid = userid or "luabot"
  g_botfullname = fullname or "new and improved with only lex and lua"

  if not reconnect(s, p) then
    log(format("couldn't connect to %s:%d\n", s, p))
  else
    log(format("connected to %s:%d\n", s, p))
  end

end

servertable =
{ ["irc.catch22.org"] = 6667,
}

function reconnect(server, port)
  local flWorked
  local p = port or 6667

  if not server then
    for s,p in servertable do

      flWorked = irc_connect(s, p)
      if flWorked then
        server, port = s, p
        break 
      end
    end

  else
    flWorked = irc_connect(server, p) 
    if flWorked then servertable[server] = p end
  end

  if flWorked then
    irc_send(format("USER %s %s %s :%s", 
            g_botuserid, "localhost", server, g_botfullname))
    irc_send(format("NICK %s", g_botnick))

    return 1
  else
    return nil
  end
end

function doline(origin, cmd, ...)
  local f = luabot[strupper(cmd)]

--  log(format("%s %s %s", origin or "NONE", cmd or "MYASS", collateparms(arg)))

  if not f then
    tinsert(arg, 1, cmd)
  end

  tinsert(arg, 1, origin)
  tinsert(arg, 1, luabot)

--  for i,v in arg do
--    print(i, v)
--  end

  return call(f or luabot.unknown, arg)
end

