#include <lua.h>

extern char *splotch_response;

// depends on the initialization function already being called
int luabot_ask(lua_State *L)
{
   const char *nick = lua_tostring(L, 1);
   const char *quest = lua_tostring(L, 2);
   int t;

   if (!nick || !quest) {
      return 0;
   }

//   t = splotch_ask(nick, quest);

   lua_pushstring(L, "The chat feature has been disabled for now.");
   return 1;
}

