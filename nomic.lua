
luabot = luabot or { }
luabot.proposals = { }

-- 101.  Any player may %propose a change to the rules

function luabot:bot_propose(origin, dest, )
  local prop = { votes = { } }

  tinsert(proposals, prop)

  return "Proposal accepted."
end

-- 102.  Any player may %vote either yes or no on each proposition.

function luabot:bot_vote(origin, dest, propno, vote)
  local prop = proposals[tonumber(propno)]

  prop.votes[origin] = vote
end

function luabot:tally_votes(prop)
  local i,v = next(prop.votes, nil)
  local yesvotes = 0, novotes = 0

  while i do
    if v == "yes" then
      yesvotes = yesvotes + 1
    else 
      novotes = novotes + 1
    end
    i,v = next(prop.votes, i)
  end

  return yesvotes, novotes
end

-- 105.  

-- 103.  A player may only %enact a proposition which has the requisite number
--       of votes.
-- 104.  A proposition may be enacted if it has 10 more yes than no votes.

function luabot:bot_enact(origin, dest, ruleno)
  local y, n = tally_votes(ruleno)
  
  if y > (n + 10) then
    -- enact as a rule
    return "Rule enacted."
  else
   return "Insufficient votes."
  end
end
