dofile("db.lua")

luabot = luabot or { }
cached_stocks = { }

luabot.players = luabot.players or { }
luabot.logins = luabot.logins or { }
backup = { }

function luabot:bot_setinfodest(origin, dest, infodest)
  luabot.infodest = infodest or luabot.infodest
  return format("information destination set to %s", luabot.infodest or "none")
end

function luabot:bot_logout(origin, dest, login)
  login = login or origin
  if self.logins[login] then 
    self.logins[login] = nil
    return format("detached %s", login)
  else
    return format("%s is not currently attached.", login)
  end
end

function luabot:bot_clear(origin, dest)
  cached_stocks = { }
end

function luabot:bot_passwd(origin, dest, passwd)
  local pl = self:get_player(origin)
  
  if not pl then
    return "you must use %login before you can %passwd"
  else
    -- does pl.name == self.logins[origin]?  it should
    pl.db.password = passwd
    return "password changed."
  end
end

function loadPlayer(email)
  local newpl =  { name = email, stocks = { }, bought = { } }
  newpl.db = opendb(newpl.name .. ".stk")
  return newpl
end
 
function luabot:bot_login(origin, dest, email, passwd)
  if self.logins[origin] then
    return "use %logout first, or %passwd to change your password"
  end

  if not email or not passwd then
    return "usage: %login <name> <passwd>"
  end

  local pl = self.players[email] or loadPlayer(email)
  local dbpwd = pl.db.password
  local ret

  if dbpwd and dbpwd ~= passwd then 
      pl.invalidPasswd = (pl.invalidPasswd or 0) + 1
      return "Invalid password."
  end

  self.players[email] = pl
  self.logins[origin] = email   -- or pl?

  if not dbpwd then
     pl.db.password = passwd
     pl.db.cashmoney = 5000.00
     ret = "New player: " .. self:bot_info(origin, dest)
  else
      ret = "Welcome back, "..email
  end

   return ret
end

function luabot:fixstocks(origin, dest)
  foreach(self.players, function (i, pl)
    db_foreach(pl, function (tickr, nshares)
      local pl = %pl
      pl.stocks[tickr] = nil
      pl.stocks[strupper(tickr)] = nshares
    end)
  end)
  return "stocks fixed."
end

function luabot:bot_die(origin, dest, passwd)
  local pl = self:get_player(origin)

  if not pl then 
    return "You aren't alive so how can you %die?" 
  end

  if pl.db.password == passwd then
    local diestr = format("You died despite having a networth of $%.2f.", calc_networth(pl))

    self.players[pl.name] = nil
    self.logins[origin] = nil
    pl.db:close()
--  might want to remove() the database file    
--    pl.stocks = { }
--    pl.cashmoney = -1

    return diestr
  else
    if passwd then return "Invalid password" else return "Password required" end
  end
end

function luabot:bot_info(origin, dest, plname)
  local pl = self.players[plname or origin] or self:get_player(origin) 

  if not pl then
    return format("not logged in.  use %%login first")
  end

--  if not pl.cached_date or not pl.cached_networth then
    pl.cached_networth, pl.cached_date = calc_networth(pl)
--  end 

  return format("'%s' has $%.2f cash, networth $%.2f (%s)", pl.name or name, 
     tonumber(pl.db.cashmoney), pl.cached_networth, pl.cached_date)
end

Help.stockrules = {
     "You may not buy stocks whose share price is less than 50 cents.",
     "Commissions are $1 per trade",
}

Help.commands = {
     "for info on a command type %help <command>",
     "stock game commands: login, logout, passwd, info, buy, sell, stock, fullquote, rankings, die",
     "admin commands: clear, ver", -- backup, restore
}

Help.login = "%login <name> <pwd>  - attaches this nick!id@host to player <name>"
Help.logout = "%logout            - detaches this nick!id@host" 
Help.passwd = "%passwd            - changes your passwd if logged in"
Help.info = "%info [<name>]     - displays cash and networth of yourself or other"
Help.buy = "%buy <n> <ticker>  - buys n vshares of ticker"
Help.sell = "%sell <n> <ticker> - sells n vshares of ticker"
Help.stock = "%stock [<tickers>] - displays specified tickers or your portfolio"
Help.fullquote = "%fullquote <ticker> - displays full information on one ticker"
Help.rankings = "%rankings [<start> <n>] - displays top <n> rankings from <start> (default first 5)"
Help.die = "%die               - commit vsuicide"

Help.clear = "%clear             - clears the stock cache"
Help.ver = "%ver               - Print bot version and the bot's nick"
Help.backup = "%backup [file]     - Save out all permanent info to ./file.sav"
Help.restore = "%restore [file] - Load permanent info back from ./file.sav to backup"

function luabot:bot_help(origin, dest, topic)
  local helpcmds

  if topic then
     helpcmds = Help[topic]
  end

  if not topic or not helpcmds then 
     local ret = "Usage: %help <topic>.  Topics available: "
     for i, v in Help do
        ret = ret .. i .. " "
     end
     return ret
  end

  if type(helpcmds) == "string" then
     return helpcmds
  end

  if type(helpcmds) == "table" then
    foreachi(helpcmds, function (i, v)
      irc_send(format("notice %s :%s", nick_from(%origin), v))
    end)
  end
    
end

function luabot:bot_backup(origin, dest, fn)
  local savefile = openfile(format("%s.sav", fn or dest), "w")

  foreach(self.players, function (name, pl)
    local savefile = %savefile

    write(savefile, format("player %s %.2f\n", pl.name, pl.cashmoney))
    write(savefile, format("passwd %s 0\n", pl.passwd or "none"))

    foreach(pl.stocks, function (ticker, n)
      write(%savefile, format("stock  %s %d\n", ticker, n))
    end)
  end)

  closefile(savefile)
  return "all information saved"
end

function luabot:bot_restore(origin, dest, chan)
  local fn = format("%s.sav", chan or dest)
  local savefile = openfile(fn, "r")
  local pl

  if not savefile then
    return format("can't open savefile %s", fn)
  end

  backup = { }

  local line = read(savefile)
  
  while line do
    local s, e, tok, str, num = strfind(line, "([^ ]*)%s*([^ ]*)%s*(-?[0-9.]*)")

    num = tonumber(num)
    if tok == "player" then
      pl = { name = str, 
             cashmoney = num or -1, stocks = { }, bought = { } }
      if not self.players[str] then
        self.players[str] = pl
      else
        backup[str] = pl
      end
--    elseif tok == "money" then
--      pl.money = num
    elseif tok == "stock" then
      pl.stocks[str] = num
    elseif tok == "passwd" then
      pl.passwd = str
    else
      -- maybe just blindly assign str=num pair?
      print("unknown token in save file")
    end

    line = read(savefile)
  end

  closefile(savefile)
  return "done loading"
end

function create_bot_move (str, flSell)
  return function (self, origin, dest, num, downticker)
    if num and downticker then
      local pl = self:get_player(origin)
      local nshares = tonumber(num)
      local ticker = strupper(downticker)
      local cost, err

      if not pl then
        return "%login first."
      end

      if %flSell then
         cost, err = moveshares(pl, -nshares, ticker)
      else
         cost, err = moveshares(pl, nshares, ticker)
      end

      return err or 
        format(%str.." %d shares of '%s' for $%.2f (plus $%.2f commission)", nshares, ticker, cost, commission(nshares))
    else
      return "usage: %buy/%sell <n> <TICKER>"
    end
  end
end

luabot.bot_buy = create_bot_move("Bought")
luabot.bot_sell = create_bot_move("Sold", -1)

function luabot:bot_quote(origin, dest, ...)
  if not arg or getn(arg) < 1 then
    return self:bot_stock(origin, dest)
  else
    --  BUG: %quote differs from %stock in that it can only take one ticker
    return self:bot_stock(origin, dest, arg[1])
  end
end


function luabot:bot_show(origin, dest, newdest, type, ...)
  local pl = self:get_player(origin)
  if not pl then return "not logged in" end

  if type == "portfolio" then
    if not arg or getn(arg) < 1 then
      self:portfolio(pl, newdest)
      return format("portfolio for %s done.", pl.name)
    else
      self:showstocks(pl, newdest, arg)
    end
  elseif type == "rankings" then
    return self:bot_rankings(nil, newdest, arg[1], arg[2])
  elseif type == "quote" then
    return self:bot_quote(origin, newdest, arg[1])
  end
end

function luabot:portfolio(pl, dest)
  pl.cached_date = nil
  pl.cached_networth = nil

  db_foreach(pl.db, function (i,v)
    if i == "cashmoney" then   -- ignore these two
    elseif i == "password" then 
    else
       cached_stocks[i] = nil
       send_stockinfo(%dest, v, i)
    end
  end)
end

function luabot:showstocks(pl, dest, stocklist)
  foreachi(stocklist, function (i,v)
    if i == "cashmoney" then   -- ignore these two
    elseif i == "password" then 
    else
      local pl = %pl or { db = { }, stocks = { } }
      local upticker = strupper(v)
      cached_stocks[upticker] = nil
      send_stockinfo(%dest, pl.db[upticker], upticker)
    end
  end)
end

function luabot:bot_shake(origin, dest, ...)
  local tonick = dest

  if dest == self.botnick then
    tonick = nick_from(origin)
  end

  if arg[1] then 
    send_stockinfo(tonick, nil, arg[1], "shake")
  else
    return "The stock ball says: " .. stockshake()
  end
end

function luabot:bot_fullquote(origin, dest, ...)
  local tonick = dest

  if dest == self.botnick then
    tonick = nick_from(origin)
  end

  if arg[1] then 
    send_stockinfo(tonick, nil, arg[1], 1)
  else
    return "usage: %fullquote <ticker>"
  end
end

function luabot:bot_stock(origin, dest, ...)
  local pl = self:get_player(origin)
  local tonick = dest

  if dest == self.botnick then
    tonick = nick_from(origin)
  end

  if getn(arg) > 0 then 
    self:showstocks(pl, tonick, arg)
  else
    if pl then
      tonick = nick_from(origin)
      self:portfolio(pl, tonick)
    else
      return format("i can't seem to find %s's portfolio. maybe %%login first?", origin)
    end
  end
end

function luabot:give(origin, dest, nick, n, ticker)
  local pl = self.players[nick]

  if pl and ticker and n and nick then
     local nshares = tonumber(n)
     local upticker = strupper(ticker)

     pl.db[upticker] = tonumber(pl.db[upticker]) + nshares
     return format("gave %s %d of %s", nick, nshares, upticker)
  else
     return format("can't give %s of %s to %s", n, ticker, nick)
  end
end

function luabot:bot_rankings(origin, dest, st, nrankstr)
  local rank = { }
  local nranks = tonumber(nrankstr) or 5
  local start = tonumber(st) or 1
  local tonick = origin and nick_from(origin) or dest

  local players = self.players

  for i,pl in players do
    if type(pl) == "table" then
      if not pl.cached_date or not pl.cached_networth then
        pl.cached_networth, pl.cached_date = calc_networth(pl)
      end
      tinsert(rank, pl)
    end
  end

  if getn(rank) < 1 then
    return "less than 1 players"
  else
    print(format("%d players to be ranked", getn(rank)))
  end

  sort(rank, function (x, y)
--    print(x.cached_networth, y.cached_networth)
    return (x.cached_networth > y.cached_networth)
  end)

  for i = start, start+nranks do
    local pl = rank[i]

    if (type(pl) == "table") then
      irc_send(format("notice %s :%d) %40s - networth $%.2f",
       tonick, i, pl.name or "unknown", pl.cached_networth))
    end
  end
  
  return "rankings done."
end

function luabot:bot_dispcurrlogin(origin, dest)
  return self.logins[origin] or "not logged in"
end

function luabot:get_player(origin)
  local currlogin = self.logins[origin]
  local pl = nil

  if type(currlogin) == "string" then
    pl = self.players[currlogin]
  elseif type(currlogin) == "table" then
    pl = currlogin
  end

  return pl
end

function luabot:bot_history(origin, dest, stockname)
  local pl = self:get_player(origin)

  local tonick = nick_from(origin)

  foreach(pl.bought, function (i, v)
    if type(v) == "table" and v.name == strupper(%stockname) then
      irc_send(format("notice %s :%s: %d shares of %s for $%.2f", %tonick,
               v.date, v.nshares, v.name, v.cost))
    end
  end)
end

function stockshake()
     local eightball = { "STRONG BUY",
                         "BUY",
                         "HOLD",
                         "ACCUMULATE",
                         "SELL",
                         "DUMP", }

     return (eightball[random(getn(eightball))] or "")
end

function send_stockinfo(nick, nshares, ticker, extendedfl)
  local upticker = strupper(ticker)
  local st = get_stock(upticker)
  local str = ""
  nshares = tonumber(nshares)

  if nshares and nshares > 0 then
    str = format(" You own %d vshares", nshares)
  end

  if extendedfl and (extendedfl == "shake") then
     str = str .. stockshake()
     extendedfl = nil
  end

  if st then
      
    if extendedfl then
      irc_send(format("notice %s :%s (%s) [%s %s]  min/last/max: $%.2f/$%.2f/$%.2f  open/current:  $%.2f/$%.2f  %+.2f  %+.2f%%  volume %d  %s",
      nick, st.name, st.ticker, st.date, st.time, st.min, st.last, st.max,
      st.open, st.price, st.variation, st.percent, st.volume, str))
    else
      irc_send(format("notice %s :%s %.2f %+.2f  %+.2f%%  %d  %s", 
         nick, st.ticker, st.price, st.variation, st.percent, st.volume, str))
    end
  else
    irc_send(format("notice %s :i am unaware of ticker '%s'", nick, upticker))
  end
end

function moveshares(pl, num, ticker)
-- to sell, num is negative; to buy, num should be positive
  local st = get_stock(ticker)
  local cost

  if st then
    cost = st.price * num
    local currentholdings = tonumber(pl.db[ticker]) or 0
    local currentmoney = tonumber(pl.db.cashmoney)
    local com = commission(num)

    if cost > currentmoney then
      return 0, format("not enough money (would cost $%.2f)", cost)
    elseif num > 0 and st.price < .50 then
      return 0, format("you cannot buy %s.  see %%help rules", ticker)
    elseif -num > currentholdings then
      return 0, format("you only have %d shares of %s", currentholdings, ticker)
    else
      pl.db.cashmoney = currentmoney - cost - commission(num)

      local tr = { name = ticker, 
                   ["cost"] = cost, 
                   nshares = num, 
                   price = st.price, date= st.date.." "..st.time }

      tinsert(pl.bought, tr)

      if currentholdings + num == 0 then
        pl.db[ticker] = nil
      else
        pl.db[ticker] = currentholdings + num
      end
    end
  else
    return 0, format("%s not a valid stock ticker", ticker)
  end

  return cost
end

function commission(n)
  return 1
end

function calc_networth(pl)
  local stat = { total = tonumber(pl.db.cashmoney) }

  db_foreach(pl.db, function (i, v)
    v = tonumber(v)
    if i == "cashmoney" then   -- ignore these two
    elseif i == "password" then 
    else
      local st = get_stock(i)
      if st then
        %stat.total = %stat.total + st.price * v
      else
        print("unknown stock in calc_networth: ", i, v)
        -- weird, a stock that was bought doesn't exist?  heh, delisted
      end
    end
  end)

  return stat.total, date()
end

function get_stock(t)
  local upticker = strupper(t)

  if cached_stocks[upticker] then
    return cached_stocks[upticker]
  else
    local ret = { ticker = upticker }

    ret.price, ret.volume, ret.variation, ret.percent,
      ret.name, ret.date, ret.time, ret.last, ret.open, ret.min, ret.max =
        c_get_stock_info(t)

    cached_stocks[upticker] = ret
    
    if type(ret.price) == "number" and ret.price > 0 then 
      return ret
    else
      return nil
    end
  end
end

