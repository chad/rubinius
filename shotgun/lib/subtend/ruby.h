#ifndef __RUBY_H
#define __RUBY_H

/* Pointers are seen as totally opaque */
typedef void * VALUE;
#define ID int

/* We need to redefine those to casts to VALUE */
#undef Qfalse
#undef Qtrue
#undef Qnil
#undef Qundef

#define Qfalse ((VALUE)0L)
#define Qtrue  ((VALUE)2L)
#define Qnil   ((VALUE)4L)
#define Qundef ((VALUE)6L)

#define SYM2ID(sym) ((ID)(sym))

extern VALUE rb_funcall(VALUE, ID, int cnt, ...);
extern VALUE rb_funcall2(VALUE, ID, int cnt, VALUE*);

extern VALUE subtend_get_global(int which);
extern VALUE subtend_get_exception(int which);

void rb_define_method_(const char *file, VALUE vmod, const char *name, void *func, int args, int kind);

#define rb_define_method(a, b, c, d) rb_define_method_(__FILE__, a, b, c, d, 0)
#define rb_define_singleton_method(a, b, c, d) rb_define_method_(__FILE__, a, b, c, d, 1)

VALUE rb_define_class(const char *name, VALUE super);
VALUE rb_define_class_under(VALUE parent, const char *name, VALUE super);

VALUE rb_define_module(const char *name);
VALUE rb_define_module_under(VALUE parent, const char *name);

VALUE rb_const_get(VALUE klass, ID id);

#define rb_cObject (subtend_get_global(0))

/* TODO: Pull these into an enum */
#define rb_eException          subtend_get_exception(0)
#define rb_eSystemExit         subtend_get_exception(1)
#define rb_eInterrupt          subtend_get_exception(2)
#define rb_eSignal             subtend_get_exception(3)
#define rb_eFatal              subtend_get_exception(4) /* WTF is this? */
#define rb_eStandardError      subtend_get_exception(5)
#define rb_eRuntimeError       subtend_get_exception(6)
#define rb_eTypeError          subtend_get_exception(7)
#define rb_eArgError           subtend_get_exception(8)
#define rb_eIndexError         subtend_get_exception(9)
#define rb_eRangeError         subtend_get_exception(10)
#define rb_eNameError          subtend_get_exception(11)
#define rb_eNoMethodError      subtend_get_exception(12)
#define rb_eSecurityError      subtend_get_exception(13)
#define rb_eNotImpError        subtend_get_exception(14)
#define rb_eNoMemError         subtend_get_exception(15)

#define rb_eScriptError        subtend_get_exception(16)
#define rb_eSyntaxError        subtend_get_exception(17)
#define rb_eLoadError          subtend_get_exception(18)

#define rb_eSystemCallError    subtend_get_exception(19)
#define rb_mErrno              subtend_get_exception(20)

void rb_raise(VALUE exc, const char *fmt, ...);

VALUE rb_obj_alloc(VALUE klass);
void rb_obj_call_init(VALUE obj, int nargs, VALUE *args);
VALUE rb_class_new_instance(int nargs, VALUE *args, VALUE klass);

/* Conversions */
int FIX2INT(VALUE val);

/* Array */
VALUE rb_ary_new(void);
VALUE rb_ary_new2(long length);
int rb_ary_size(VALUE self);
VALUE rb_ary_push(VALUE array, VALUE val);
VALUE rb_ary_entry(VALUE array, int offset);
VALUE rb_ary_clear(VALUE array);
VALUE rb_ary_dup(VALUE array);
VALUE rb_ary_unshift(VALUE array, VALUE val);
VALUE rb_ary_shift(VALUE array);
void rb_ary_store(VALUE array, int offset, VALUE val);

/* String */
VALUE rb_str_new(const char *ptr, long len);
VALUE rb_str_new2(const char *ptr);
VALUE rb_str_dup(VALUE str);
VALUE rb_str_buf_cat(VALUE str, const char *ptr, long len);

/* Hash */
VALUE rb_hash_new(void);
VALUE rb_hash_aref(VALUE hash, VALUE key);
VALUE rb_hash_aset(VALUE hash, VALUE key, VALUE val);
VALUE rb_hash_delete(VALUE hash, VALUE key);

char *rb_id2name(ID sym);
ID rb_intern(const char *name);

#endif
