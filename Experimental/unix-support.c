/* Minimal support for Unix-style error codes */

/* On SunOS5, compile with
   gcc -fPIC -shared unix-support.c -lsocket -lnsl -o unix-support.so
 */

extern int errno;
extern int h_errno;

int get_errno( void ) { return errno; }
int get_h_errno( void ) { return h_errno; }

/* eof */
