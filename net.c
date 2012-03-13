#include <stdio.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <netdb.h>

#include <lua40/lua.h>

struct net {
  int sock;
  FILE *readfp;
};

extern lua_State *g_state;

struct net g_irccnxn;
extern FILE *yyin;

int ConnectToServer(struct net *, char *server, int port);

int reconnect(void);

int irc_connect(lua_State *L)
{
   char *serv = (char *) lua_tostring(L, -2);
   int port = lua_tonumber(L, -1);

   int s = ConnectToServer(&g_irccnxn, serv, port);

   if (s < 0) {
     return 0;                        
   }
    
   yyin = fdopen(s, "r+b");

   if (yyin == NULL) {
     return 0;
   }

   lua_pushstring(L, "exito");
   return 1;                        
}

#if 0
typedef struct in_addr in_addr_t;
typedef u_long in_addr_t;
#endif

in_addr_t GetIPFromString(char *name)
{
	in_addr_t		addr;
	struct hostent	*host;

   addr = inet_addr(name);
	if (addr == INADDR_NONE) {
		host = gethostbyname(name);
		if(host==NULL) {
			herror(NULL);
			addr = 0;
      }
		else
			memcpy(&addr, host->h_addr_list[0], sizeof(addr));
	}
	return addr;
}

/* returns fd or <0 on error */
int ConnectToServer(struct net *n, char *server, int port)
{
  int sock, err;
  struct sockaddr_in s;

  sock = socket(PF_INET, SOCK_STREAM, 0);
  if (sock < 0) {
		perror("couldn't get socket");
		return -1;
  }

  s.sin_family = PF_INET;
  s.sin_port = htons(port);
  s.sin_addr.s_addr = GetIPFromString(server);

  err = connect(sock, (struct sockaddr *) &s, sizeof(s));
  if (err) {
		perror("couldn't connect to server");
		return -1;
  }

  fcntl(sock, F_SETFL, O_NDELAY);

  n->sock = sock;
  n->readfp = fdopen(sock, "r");
  setlinebuf(n->readfp);   /* line buffering makes for better parsing */

  return sock;
}

int irc_send(char *str)
{
   int err;
   char buf[512];

   if (str)  strncpy(buf, str, 255);
   strcat(buf, "\r\n");   /* can't hurt */

/*   printf("=> '%s'\n", str);*/

     err = write(g_irccnxn.sock, buf, strlen(buf));

     if (err < 0)  {
        fprintf(stderr, "can't send to irc connection\n");
     } else {
/*        fprintf(stderr, "sent '%s'\n", str); */
     }
      

   return err;
}

int wait_for_input(void)
{
   fd_set readfds, writefds, errfds;
   int err;

   int highestfd = 0;

   do {
     FD_ZERO(&readfds);
     FD_ZERO(&writefds);
     FD_ZERO(&errfds);

     FD_SET(g_irccnxn.sock, &readfds);
     FD_SET(g_irccnxn.sock, &writefds);
     FD_SET(g_irccnxn.sock, &errfds);
     highestfd = g_irccnxn.sock;
     
     err = select(highestfd+1, &readfds, NULL, &errfds, NULL);

     if (FD_ISSET(g_irccnxn.sock, &readfds))   /* IRC is calling.. */
         return 1;
#if 0
     if (FD_ISSET(g_irccnxn.sock, &writefds))   /* IRC is calling.. */
        return 1;
#endif
     if (FD_ISSET(g_irccnxn.sock, &errfds)) {  /* some kind of error.. */
         sleep(1);
         reconnect();
     }

     /* handle other network connections here */
   } while (err < 0);

   return 0;  /* ?? */
}

void hup_handler(int s)
{
    close(g_irccnxn.sock);
    reconnect();
}

