
#include <unistd.h>
#include <string.h>
#include <stdio.h>

#include <lua.h>

#include "stocks.h"

/* called from lua, returns price, volume, variation, percentVariation */
int get_stock_info(lua_State *L)
{
  char *ticker = (char *) lua_tostring(L, -1);
  stock *s;

  s = (stock *) malloc(sizeof(stock));
  
  if (s == NULL)  {
     lua_pushnil(L);
     return 1;
  }

#define SAFESTR(s) ((s == NULL) ? "(null)" : s)

  get_stocks(ticker, &s);
  
  lua_pushnumber(L, s->CurrentPrice);
  lua_pushnumber(L, s->Volume);
  lua_pushnumber(L, s->Variation);
  lua_pushnumber(L, s->Pourcentage);

  lua_pushstring(L, SAFESTR(s->Name));
  lua_pushstring(L, SAFESTR(s->Date));
  lua_pushstring(L, SAFESTR(s->Time));
  lua_pushnumber(L, s->LastPrice);
  lua_pushnumber(L, s->OpenPrice);
  lua_pushnumber(L, s->MinPrice);
  lua_pushnumber(L, s->MaxPrice);

  free(s);

  return 11;
}

