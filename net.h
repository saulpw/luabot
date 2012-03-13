#ifndef NET_H
#define NET_H

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


#include "user.h"

struct net {
  int sock;
  FILE *readfp;

  struct user me;
};

int ConnectToServer(struct net *, char *server, int port);

#endif
