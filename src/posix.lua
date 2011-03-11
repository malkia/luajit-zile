local ffi = require( "ffi" )
local C = ffi.C

ffi.cdef[[
      char* basename(const char*);
      char* getcwd(char*, int);
      char* getpass(char*);
      int isprint(int);
      int isgraph(int);
      int getopt_long(int argc, char * const *argv, const char *optstring, 
		      const struct option *longopts, int *longindex);
]]

posix = {
   raise     = function(s) end,
   isprint   = function(s) return C.isprint(s:byte(1)) end,
   isgraph   = function(s) return C.isgraph(s:byte(1)) end,
   basename  = function(s) return ffi.string(C.basename(s)) end,
   getcwd    = function()
		  local size = 2048
		  local buf = ffi.new( "char[?]", size )
		  return ffi.string(C.getcwd(buf,size))
	       end,
   getpasswd = function()
		  local size = 2048
		  local buf = ffi.new( "char[?]", size )
		  return ffi.string(C.getpass(buf))
	       end,
   signal    = {},
   SIGHUP    = 1,
   SIGINT    = 2,
   SIGBUS    = 10,
   SIGSEGV   = 11,
   SIGTERM   = 15,
   SIGTSTP   = 18,
}

function posix.getopt_long( arg, opts, longopts )
   return function(...)
	     return nil, nil, nil, nil
	  end
end
