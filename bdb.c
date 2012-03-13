#include <lua.h>

#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <limits.h>

#ifdef NORMAL_SYSTEM
#include <db.h>
#else
#include <db_185.h>   // sleepycat for some reason
#endif

#define LUA_SETFUNC(L, T, N, F) \
   lua_pushstring(L, (N));      \
   lua_pushcfunction(L, (F));   \
   lua_settable(L, (T));      

#define GETDB(DBVAR) \
   DB *DBVAR; \
   lua_pushstring(L, "__db__"); \
   lua_gettable(L, 1); \
   DBVAR = (DB *) lua_touserdata(L, -1);

typedef struct {
   int luaType;
   char buf[0];
} luadbt;

// puts the lua data at index into dbt
int db_luaToDBT(lua_State *L, DBT *dbt, int index)
{
   int t = lua_type(L, index);
   size_t sz = 0;
   luadbt *ld = NULL;

   switch (t) {
     case LUA_TNUMBER:
        { 
           double d = lua_tonumber(L, index);
           int dsz = sizeof(d);

           sz = (size_t) dsz + sizeof(luadbt);
           ld = (luadbt *) malloc(sz);
           memcpy(ld->buf, &d, sz);
        }
        break;
     case LUA_TSTRING:
        {
           const char *val = lua_tostring(L, index);
           int strsz = lua_strlen(L, index) ;
 
           sz = (size_t) strsz + sizeof(luadbt);
           ld = (luadbt *) malloc(sz);
           memcpy(ld->buf, val, strsz);
        }
        break;
     case LUA_TNIL:
     default:
        lua_error(L, "db_luaToDBT: invalid type for database thang");
        break;
   };

   ld->luaType = t;
   dbt->data = (void *) ld;
   dbt->size = sz;
}

// pushes a native lua type onto the stack representing dbt
int db_DBTtoLua(lua_State *L, DBT *dbt)
{
   luadbt *ld = (luadbt *) dbt->data;
   int sz = dbt->size;
   
   switch (ld->luaType) {
     case LUA_TNUMBER: {
        double *d = (double *) ld->buf;
        lua_pushnumber(L, *d);
     }
     break;

     case LUA_TSTRING:
        lua_pushlstring(L, ld->buf, sz - sizeof(luadbt));
        break;
   
     case LUA_TNIL:
     default:
        lua_error(L, "db_DBTtoLua: invalid type for database thang");
        break;
   };
}

int db_close(lua_State *L)
{
   GETDB(db)

   if (db->close(db) < 0)  
      lua_error(L, "error on db_close();");

   return 0;
}

int db_del(lua_State *L)
{
   DBT key;
   GETDB(db)
   
   db_luaToDBT(L, &key, 2);
   
   if (db->del(db, &key, 0) < 0)  
     lua_error(L, "error on db_del();");

   return 0;
}

int db_get(lua_State *L)
{
   DBT key, val;
   int r;
   GETDB(db)

   db_luaToDBT(L, &key, 2);

   r = db->get(db, &key, &val, 0);

   if (r < 0) {
       lua_error(L, "error on db_get();");
   } else if (r == 0) { 
       db_DBTtoLua(L, &val);
    
       return 1;
   } else { 
       return 0;
   }
}

int db_put(lua_State *L)
{
   DBT key, val;
   GETDB(db)

   db_luaToDBT(L, &key, 2);
   db_luaToDBT(L, &val, 3);

// printf("db[%s] = %s\n", key.data, val.data);

   if (db->put(db, &key, &val, 0) < 0)  lua_error(L, "error on db_put();");

   return 0;
}

int db_sync(lua_State *L)
{
   GETDB(db)
   if (db->sync(db, 0) < 0)  lua_error(L, "error on db_sync();");
// printf("db->sync\n");
   return 0;
}

#define DBSEQ(NAME, FLAG) \
   int NAME(lua_State *L) { return db_seq(L, FLAG); }

DBSEQ(db_first, R_FIRST)
DBSEQ(db_next, R_NEXT)
DBSEQ(db_cursor, R_CURSOR)

#if 0
   DBSEQ(db_last, R_LAST)
   DBSEQ(db_prev, R_PREV)
#endif

int db_seq(lua_State *L, u_int flag)
{
   DBT key, val;
   int r;
   GETDB(db)

   r = db->seq(db, &key, &val, flag);

   if (r < 0) {           // error
      lua_error(L, "error on db_seq()");
   } else if (r > 0) {    // no more keys
      return 0;
   } else {               // regular
      db_DBTtoLua(L, &key);
      db_DBTtoLua(L, &val);
      return 2;
   } 
}

static int g_dbtag = LUA_ANYTAG;

int db_init(lua_State *L)
{
   const char *fn = (const char *) lua_tostring(L, 1);

   DB *db = dbopen(fn, O_CREAT | O_RDWR, 
                       S_IRUSR | S_IWUSR, 
                       DB_HASH,           /* or DB_BTREE or DB_RECNO, */
                       NULL);

   if (db == NULL) {
       lua_error(L, "error on db_init()");
   }

   if (g_dbtag == LUA_ANYTAG) {
       g_dbtag = lua_newtag(L);
   }

   lua_newtable(L);                        /* local t */

   lua_pushstring(L, "__db__");
   lua_pushuserdata(L, db);
   lua_settable(L, -3);                    /* t["__db__"] = userdata(DB *db) */

   LUA_SETFUNC(L, -3, "close", db_close);
   LUA_SETFUNC(L, -3, "del", db_del);
   LUA_SETFUNC(L, -3, "first", db_first);
   LUA_SETFUNC(L, -3, "next", db_next);
   LUA_SETFUNC(L, -3, "get", db_get);
   LUA_SETFUNC(L, -3, "put", db_put);
   LUA_SETFUNC(L, -3, "sync", db_sync);

   lua_settag(L, g_dbtag);

   return 1;
}
