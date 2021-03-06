#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <netdb.h>
#include <errno.h>
#include <time.h>

#include "shotgun/lib/shotgun.h"
#include "shotgun/lib/symbol.h"
#include "shotgun/lib/object.h"
#include "shotgun/lib/tuple.h"
#include "shotgun/lib/hash.h"
#include "shotgun/lib/string.h"
#include "shotgun/lib/primitive_indexes.h"

int ffi_errno() { return errno; }

void ffi_set_errno(int n) {
  errno = n;
}

time_t ffi_timezone() {
  return timezone;
}

char* ffi_tzname(int dst) {
  if(dst) {
    return tzname[1];
  } else {
    return tzname[0];
  }
}

/*
int ffi_daylight() {
  return daylight;
}
*/

OBJECT ffi_new_pointer(STATE, void *ptr) {
  void **code_start;
  OBJECT obj;
  
  NEW_STRUCT(obj, code_start, BASIC_CLASS(ffi_ptr), void*);
  *code_start = (void*)ptr;
  
  return obj;
}

void ffi_autorelease(OBJECT ptr, int ar) {
  type_assert(ptr, MemPtrType, "passing a pointer");
  ptr->RequiresCleanup = (ar ? 1 : 0);
}

void ffi_set_address(OBJECT ptr, void *addr) {
  type_assert(ptr, MemPtrType, "passing a pointer");
  *DATA_STRUCT(ptr, void**) = addr;
}

uintptr_t ffi_address(void *ptr) {
  return (uintptr_t)ptr;
}

int ffi_write_int(int *ptr, int val) {
  *ptr = val;
  return val;
}

int ffi_read_int(int *ptr) {
  return *ptr;
}

long ffi_write_long(long *ptr, long val) {
  *ptr = val;
  return val;
}

long ffi_read_long(long *ptr) {
  return *ptr;
}

double ffi_write_float(double *ptr, double val) {
  *ptr = val;
  return val;
}

double ffi_read_float(double *ptr) {
  return *ptr;
}

char *ffi_read_string(char *ptr) {
  return ptr;
}

OBJECT ffi_read_string_length(STATE, void *ptr, int len) {
  OBJECT str = string_new2(state, NULL, len);
  
  memcpy(rbx_string_as_cstr(state, str), ptr, len);
  
  return str;
}

int ffi_write_string_length(STATE, void *ptr, void* str, int len) {
  void *src = rbx_string_as_cstr(state, str);
  
  memcpy(ptr, src, len);
  
  return len;
}

void *ffi_read_pointer(void **ptr) {
  return *ptr;
}

char *ffi_sprintf_f(double value, int size, char *fmt) {
  char *str = ALLOC_N(char, size);
  snprintf(str, size, fmt, value);
  return str;
}

char *ffi_sprintf_d(int value, int size, char *fmt) {
  char *str = ALLOC_N(char, size);  
  snprintf(str, size, fmt, value);
  return str;
}

void *ffi_add_ptr(char *ptr, int offset) { 
  return (void*)(ptr + offset); 
}

unsigned int ffi_cast(unsigned int val) {
  return val;
}

long ffi_major(dev_t n) {
#if defined(major)
  return major(n);
#else
  return -1;
#endif
}

long ffi_minor(dev_t n) {
#if defined(minor)
  return minor(n);
#else
  return -1;
#endif
}

/* FIXME: these are TEMPORARY until we determine how to
 * have FFI resolve symbols that may be macros. This is
 * used rather than a primitive so that it is easier to
 * replace (unlike primitives).
 */
int ffi_stat(const char *path, struct stat *buf) {
  return stat(path, buf);
}

int ffi_fstat(int filedes, struct stat *buf) {
  return fstat(filedes, buf);
}

int ffi_lstat(const char *path, struct stat *buf) {
  return lstat(path, buf);
}
