cfg_BlogOutputDir = "/home/pswanson/public_html/irc/"

Help.blogfile = {
  "%blogfile <filename>    -- creates a new blog entry",
  "the first line after %blogfile should be the entry's title (in bold); all subsequent lines are entered as plaintext (<p>'s are inserted between each line); simple HTML markup commands should work as expected.",
  "when the entry is finished, type %blogend on a line by itself.",
  "see your blog entry at http://www.meat.net/~pswanson/irc/",
}

Help.blogend = "%blogend   -- closes the blog entry you were working on"

function removeDangerousFilenameChars(fn)
   return gsub(fn, "%.", "")
end

g_Blogs = g_Blogs or { }

function luabot:bot_blogfile(orig, dest, filename)
   local nick = nick_from(orig)
   local blog = g_Blogs[nick]

   if blog then
      return "You've been blogging to " ..  blog.name .. " this entire time!"
   end

   if type(filename) ~= "string" then
      return "Usage: %blogfile <filename>"
   end

   local f = openfile(cfg_BlogOutputDir .. 
                      removeDangerousFilenameChars(filename) .. ".txt", "a+")

   if not f then
      return format("Error opening blogfile '%s'", filename)
   end

   g_Blogs[nick] = { name = filename, fileptr = f, owner = orig }

   return format("blogfile '%s' opened; type %%blogend when done appending", filename)
end

function luabot:bot_blogend(orig, dest)
   local nick = nick_from(orig)
   local blog = g_Blogs[nick]

   if not blog then
      return "You don't have a blog open.  Perhaps you changed nicknames?"
   end

   local f = blog.fileptr
   write(f, format("-- %s at %s\n<br><p>", nick, date("%Y-%m-%dT%H:%M:%S%z")))
   flush(f)
   closefile(f)

   g_Blogs[nick] = nil

   return format("blogfile '%s' closed", blog.name)
end

-- for %rehashes
luabot.BlogOldPRIVMSG = luabot.BlogOldPRIVMSG or luabot.PRIVMSG

function luabot:PRIVMSG(orig, user, msg)
   self:BlogOldPRIVMSG(orig, user, msg)

   if strfind(msg, "%%blog") then -- one of our commands
      return 
   end

   local blog = g_Blogs[nick_from(orig)]

   if blog then
      write(blog.fileptr, format("%s\n<p>", msg))
   end
end

if test then

end

