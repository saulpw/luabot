#ifndef IRCBOT_H
#define IRCBOT_H

#include <stdio.h>

#include <lua40/lua.h>

int splotch_init(void);
int splotch_ask(const char *);
extern char *splotch_response;

int irc_send(char *buf);
/* int irc_connect(char *server, int port); */
int irc_wait(void);
FILE *irc_getreadfp(void);

int do_bot_cmd(char *orig, char *cmd, char *dest, char *parm);

#endif

