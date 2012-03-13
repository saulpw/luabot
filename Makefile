
LEX=flex

EXEC= luabot
OBJS= main.o net.o bdb.o stock.o chat.o lex.yy.o
SRCS= main.c net.c bdb.c stock.c chat.c lex.yy.c

LIBS= -llua40 -llualib40 -lm -lstocks -ldb
INCLUDES= -I/usr/include/lua40

luabot: $(OBJS) $(HDRS)
	gcc -ggdb $(OBJS) -o $@ $(LIBS)

.c.o:
	gcc -O2 -ggdb -c $(INCLUDES) $< -o $@

#.cc.o:
#	g++ -O -c $< -o $@

lex.yy.c: ircproto.l
	$(LEX) ircproto.l

lint:
	$(LINT) $(INCLUDES) $(SRCS)

clean:
	rm $(OBJS)
	rm $(EXEC)

tarball: 
	tar -cvf luabot-1.1.tar $(SRCS) Makefile *.h *.l *.lua

