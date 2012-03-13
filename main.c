#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

#include <lua40/lua.h>

#include "ircbot.h"

int yylex(void);
extern FILE *yyin;
lua_State *g_state;

int send_to_irc(lua_State *L);
int irc_connect(lua_State *L);
int get_stock_info(lua_State *L);
int luabot_ask(lua_State *L);
int check_for_error(int err);
int db_init(lua_State *L);

char *g_ircserver = NULL;
int g_ircport = 0;

char *g_botnick = NULL;
char *g_botuserid = NULL;
char *g_botfullname = NULL;

void hup_handler(int s);

void shutdown(void)
{
}

int reconnect(void)
{
     lua_getglobal(g_state, "reconnect");
     if (check_for_error(lua_call(g_state, 0, 0))) {
        fprintf(stderr, "lua error on reconnect()\n");
        return 0;
     }

     return 1;
}

int send_to_irc(lua_State *L)
{
   int err;
   int nreconnects = 0;

   do {
     err = irc_send((char *) lua_tostring(L, -1));
     if (err < 0) { 
       sleep(5);
       reconnect();
       nreconnects++;
     }
   } while (err < 0);
   
   lua_pushnumber(L, (double) nreconnects);
   return 1;
}

main(int argc, char *argv[])
{
   lua_State *L = NULL;
   char ch;

   do { 
      ch = getopt(argc, argv, "u:n:p:s:");

      switch(ch) {
      case 'n':  /* bot nickname */
        g_botnick = strdup(optarg);
        break;
      case 'u':  /* bot user id */
        g_botuserid = strdup(optarg);
        break;
      case 'p':  /* IRC port */
        g_ircport = atoi(optarg);
	break;
      case 's':  /* IRC server */
        g_ircserver = strdup(optarg);
	break;
      case EOF:  /* no more options  */
	break;
      case ':':  /* missing parameter */
      case '?':  /* unknown option */
      default: 
        fprintf(stderr, "\t -s <IRC server> -p <IRC port>\n"
                "\t -n <nickname> -u <userid>\n");
	exit(1);
      };
   } while (ch != EOF);

   g_state = L = lua_open(0);
   lua_baselibopen(L);
   lua_strlibopen(L);
   lua_iolibopen(L);
   lua_mathlibopen(L);

   lua_register(L, "irc_send", send_to_irc);
   lua_register(L, "irc_connect", irc_connect);
   lua_register(L, "c_get_stock_info", get_stock_info);
   lua_register(L, "db_init", db_init);

   signal(SIGHUP, hup_handler);

//   splotch_init();
   lua_register(L, "chat_ask", luabot_ask);

   lua_dofile(L, "main.lua");

   lua_getglobal(L, "init");
   if (g_botnick)     lua_pushstring(L, g_botnick);  else lua_pushnil(L);
   if (g_botuserid)   lua_pushstring(L, g_botuserid); else lua_pushnil(L);
   if (g_botfullname) lua_pushstring(L, g_botfullname); else lua_pushnil(L);
   if (g_ircserver)   lua_pushstring(L, g_ircserver); else lua_pushnil(L);
   if (g_ircport > 0) lua_pushnumber(L, g_ircport); else lua_pushnil(L);
   if (check_for_error(lua_call(L, 5, 0))) {
      fprintf(stderr, "error calling init()\n");
      exit(1);
   }

   do {
      int nparms;

      lua_getglobal(L, "doline");

      nparms = lua_gettop(L);

      /* pushes successive arguments on g_state for us */
      yylex();

      nparms = lua_gettop(L) - nparms;

      if (nparms > 0) {
        if (check_for_error(lua_call(L, nparms, 0))) {
           fprintf(stderr, "error in doline()\n");
        }
      } else
        lua_pop(L, 1);

   } while (1);
}

int check_for_error(int err) {
   char *errstr;

   switch (err) {
   case LUA_ERRRUN:    /* - error while running the chunk.  */
      errstr = "LUA_ERRRUN"; break;

   case LUA_ERRSYNTAX: /* - syntax error during pre-compilation.  */
      errstr = "LUA_ERRSYNTAX"; break;

   case LUA_ERRMEM:    /* - memory allocation error.  */
      errstr = "LUA_ERRMEM"; break;

   case LUA_ERRERR:    /* - error while running _ERRORMESSAGE. */
      errstr = "LUA_ERRERR"; break;

   case LUA_ERRFILE:   /* - error opening the file */
      errstr = "LUA_ERRFILE"; perror(NULL); break;

   default:  return 0;
   };

   fprintf(stderr, "%s happened.\n", errstr);
   return 1;
}
