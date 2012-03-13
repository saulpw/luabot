
function opendb(fn)
   local db = db_init(fn)
   local t = tag(db)

   settagmethod(t, "index", function (t, i, v) 
         return t:get(i) 
   end)

   settagmethod(t, "settable", function (t, i, v) 
         if v then 
            t:put(i, v) 
         else
            t:del(i) 
         end
         t:sync()
   end)

   db_foreach = function (t, f)  -- make work like lua's
      local i, v = t:first()

      while i do
         local r = f(i, v)
         if r then return r end
         i, v = t:next()
      end
   end

   return db
end

