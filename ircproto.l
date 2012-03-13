%{

#include <unistd.h>
#include <string.h>

#include <lua.h>

extern lua_State *g_state;

int wait_for_input(void);

#define yywrap() 1
#define YY_SKIP_YYWRAP

#define YY_INPUT(buf,result,max_size)           \
    {                                           \
      int c = '*', n;                           \
\
      for (n = 0; n < max_size; ) { \
         c = getc(yyin); \
         if (c == EOF)                          \
            wait_for_input();                   \
         else                                   \
            buf[n++] = (char) c;                \
                                                \
         if ( (c == '\r') || (c == '\n') )  {   \
            break;                              \
         }                                      \
      }                                         \
      result = n;                               \
    }

%}

newline	[\n\r]
nonws		[^ \n\r]
word		{nonws}+

%s CMD PARMS

%%

<<EOF>>                   { BEGIN INITIAL; return 0; }

<INITIAL>^:{word}         { lua_pushstring(g_state, &yytext[1]); BEGIN CMD; }
<INITIAL>{word}           { lua_pushnil(g_state); 
                            lua_pushstring(g_state, yytext); BEGIN PARMS; }

<CMD>{word}               { lua_pushstring(g_state, yytext); BEGIN PARMS; }

<PARMS>:[^\n\r]*          { lua_pushstring(g_state, &yytext[1]); 
                            BEGIN INITIAL; 
                          }
<PARMS>{word}             { lua_pushstring(g_state, yytext); }

{newline}                 { BEGIN INITIAL; return 1; }

.                         ;

%%

