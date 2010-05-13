/* Global function prototypes

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010 Free Software Foundation, Inc.

   This file is part of GNU Zile.

   GNU Zile is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   GNU Zile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNU Zile; see the file COPYING.  If not, write to the
   Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
   MA 02111-1301, USA.  */

#include <lua.h>
#include "gl_xlist.h"

#include "xalloc_extra.h"

/* basic.c ---------------------------------------------------------------- */
size_t get_goalc_bp (Buffer * bp, Point * pt);
size_t get_goalc (void);
bool previous_line (void);
bool next_line (void);
bool backward_char (void);
bool forward_char (void);
void gotobob (void);
void gotoeob (void);

/* bind.c ----------------------------------------------------------------- */
const char * last_command (void);
void set_this_command (const char * cmd);
size_t do_binding_completion (astr as);
gl_list_t get_key_sequence (void);
const char * get_function_by_keys (gl_list_t keys);
void process_command (void);
void init_default_bindings (void);

/* buffer.c --------------------------------------------------------------- */
#define FIELD(ty, field)                                \
  ty get_buffer_ ## field (const Buffer *bp);           \
  void set_buffer_ ## field (Buffer *bp, ty field);
#define FIELD_STR(field)                                \
  FIELD(const char *, field)
#include "buffer.h"
#undef FIELD
#undef FIELD_STR
#define FIELD(ty, field)                                \
  ty get_region_ ## field (const Region *cp);           \
  void set_region_ ## field (Region *cp, ty field);
#include "region.h"
#undef FIELD
void free_buffer (Buffer * bp);
void init_buffer (Buffer * bp);
Buffer * buffer_new (void);
const char *get_buffer_filename_or_name (Buffer * bp);
void set_buffer_names (Buffer * bp, const char *filename);
Buffer * find_buffer (const char *name);
void switch_to_buffer (Buffer * bp);
Region * region_new (void);
int warn_if_readonly_buffer (void);
int calculate_the_region (Region * rp);
bool delete_region (const Region * rp);
bool in_region (size_t lineno, size_t x, Region * rp);
void set_temporary_buffer (Buffer * bp);
size_t calculate_buffer_size (Buffer * bp);
int transient_mark_mode (void);
void activate_mark (void);
void deactivate_mark (void);
size_t tab_width (Buffer * bp);
astr copy_text_block (Point * pt, size_t size);
Buffer *create_scratch_buffer (void);
void kill_buffer (Buffer * kill_bp);
bool check_modified_buffer (Buffer * bp);

/* completion.c ----------------------------------------------------------- */
#define FIELD(cty, lty, field)                                  \
  cty get_completion_ ## field (int cp);
#include "completion.h"
#undef FIELD
void popup_completion (int cp);
char *minibuf_read_variable_name (char *fmt, ...);
int make_buffer_completion (void);

/* editfns.c -------------------------------------------------------------- */
void push_mark (void);
void pop_mark (void);
void set_mark (void);
bool is_empty_line (void);
bool is_blank_line (void);
int following_char (void);
int preceding_char (void);
bool bobp (void);
bool eobp (void);
bool bolp (void);
bool eolp (void);
void ding (void);

/* file.c ----------------------------------------------------------------- */
extern char coding_eol_lf[3];
extern char coding_eol_crlf[3];
extern char coding_eol_cr[3];
extern char coding_eol_undecided[3];
int exist_file (const char *filename);
astr get_home_dir (void);
astr agetcwd (void);
bool expand_path (astr path);
astr compact_path (astr path);
bool find_file (const char *filename);
void zile_exit (int doabort);

/* funcs.c ---------------------------------------------------------------- */
void set_mark_interactive (void);
void write_temp_buffer (const char *name, bool show, void (*func) (va_list ap), ...);

/* getkey.c --------------------------------------------------------------- */
void pushkey (size_t key);
void ungetkey (size_t key);
size_t lastkey (void);
size_t xgetkey (int mode, size_t timeout);
size_t getkey (void);
void waitkey (size_t delay);
void init_getkey (void);

/* keycode.c -------------------------------------------------------------- */
astr chordtostr (size_t key);
size_t strtochord (const char *buf, size_t * len);
gl_list_t keystrtovec (const char *key);
astr keyvectostr (gl_list_t keys);

/* killring.c ------------------------------------------------------------- */
void free_kill_ring (void);

/* line.c ----------------------------------------------------------------- */
#define FIELD(cty, lty, field)                          \
  cty get_line_ ## field (int l);                       \
  void set_line_ ## field (int l, cty field);
#define TABLE_FIELD(field)                      \
  int get_line_ ## field (int l);               \
  void set_line_ ## field (int l, int v);
#include "line.h"
#undef FIELD
#undef TABLE_FIELD
void line_replace_text (int lp, size_t offset, size_t oldlen,
                        char *newtext, int replace_case);
int insert_char (int c);
int insert_char_in_insert_mode (int c);
bool fill_break_line (void);
bool insert_newline (void);
void insert_nstring (const char *s, size_t len);
void insert_astr (astr as);
void bprintf (const char *fmt, ...);
bool delete_char (void);

/* lisp.c ----------------------------------------------------------------- */
extern le leNIL, leT;
le execute_with_uniarg (bool undo, int uniarg, bool (*forward) (void),
                        bool (*backward) (void));
le execute_function (const char *name, int uniarg, bool is_uniarg, le list);
bool function_exists (const char *name);
int get_function_interactive (const char *name);
const char *get_function_doc (const char *name);
const char *minibuf_read_function_name (const char *fmt, ...);
void init_lisp (void);

/* lcurses.c -------------------------------------------------------------- */
int luaopen_curses (lua_State *L);

/* lua.c ------------------------------------------------------------------ */
int lua_debug (lua_State *L);
int lua_refeq (lua_State *L, int r1, int r2);

/* macro.c ---------------------------------------------------------------- */
void cancel_kbd_macro (void);
void add_cmd_to_macro (void);
void add_key_to_cmd (size_t key);
void remove_key_from_cmd (void);
void call_macro (Macro * mp);
Macro *get_macro (const char *name);
void add_macros_to_list (int l);

/* main.c ----------------------------------------------------------------- */
CLUE_DECLS(L);
extern char *prog_name;
extern int cur_wp, head_wp;
extern Buffer *cur_bp, *head_bp;
extern int thisflag, lastflag, last_uniarg;

/* marker.c --------------------------------------------------------------- */
#define FIELD(cty, lty, field)                  \
  cty get_marker_ ## field (int wp);            \
  void set_marker_ ## field (int wp, cty field);
#define TABLE_FIELD(field)                        \
  int get_marker_ ## field (int l);               \
  void set_marker_ ## field (int l, int v);
#include "marker.h"
#undef FIELD
#undef TABLE_FIELD
int marker_new (void);
void free_marker (int marker);
void move_marker (int marker, Buffer * bp, Point * pt);
int copy_marker (int marker);
int point_marker (void);

/* minibuf.c -------------------------------------------------------------- */
extern char *minibuf_contents;
void init_minibuf (void);
void minibuf_error (const char *fmt, ...);
void minibuf_write (const char *fmt, ...);
char *minibuf_read (const char *fmt, const char *value, ...);
unsigned long minibuf_read_number (const char *fmt, ...);
bool minibuf_test_in_completions (const char *ms, int cp);
int minibuf_read_yn (const char *fmt, ...);
int minibuf_read_yesno (const char *fmt, ...);
char *minibuf_read_completion (const char *fmt, char *value, int cp,
                               int hp, ...);
char *minibuf_vread_completion (const char *fmt, char *value, int cp,
                                int hp, const char *empty_err,
                                bool (*test) (const char *s, int cp),
                                const char *invalid_err, va_list ap);
char *minibuf_read_filename (const char *fmt, const char *value,
                             const char *file, ...);
void minibuf_clear (void);

/* point.c ---------------------------------------------------------------- */
#define FIELD(ty, field)                                \
  ty get_point_ ## field (const Point * pt);            \
  void set_point_ ## field (Point * pt, ty field);
#include "point.h"
#undef FIELD
Point *point_new (void);
Point *make_point (size_t lineno, size_t offset);
Point *point_copy (Point *pt);
int cmp_point (Point * pt1, Point * pt2);
int point_dist (Point * pt1, Point * pt2);
int count_lines (Point * pt1, Point * pt2);
Point *point_min (void);
Point *point_max (void);
Point *line_beginning_position (int count);
Point *line_end_position (int count);
void goto_point (Point * pt);

/* redisplay.c ------------------------------------------------------------ */
void resync_redisplay (void);
void resize_windows (void);
void recenter (int wp);

/* search.c --------------------------------------------------------------- */
void init_search (void);

/* term_minibuf.c --------------------------------------------------------- */
void term_minibuf_write (const char *fmt);
char *term_minibuf_read (const char *prompt, const char *value, size_t pos,
                         int cp, int hp);

/* term_redisplay.c ------------------------------------------------------- */
void term_set_size (size_t cols, size_t rows);
void term_redisplay (void);
void term_full_redisplay (void);
void show_splash_screen (const char *splash);

/* undo.c ----------------------------------------------------------------- */
extern int undo_nosave;
void undo_start_sequence (void);
void undo_end_sequence (void);
void undo_save (int type, Point * pt, size_t arg1, size_t arg2);
void free_undo (Undo *up);
void undo_set_unchanged (Undo *up);

/* variables.c ------------------------------------------------------------ */
void init_variables (void);
void set_variable (const char *var, const char *val);
const char *get_variable_bp (Buffer * bp, const char *var);
const char *get_variable (const char *var);
long get_variable_number_bp (Buffer * bp, const char *var);
long get_variable_number (const char *var);
bool get_variable_bool (const char *var);

/* window.c --------------------------------------------------------------- */
#define FIELD(cty, lty, field)                  \
  cty get_window_ ## field (int wp);            \
  void set_window_ ## field (int wp, cty field);
#define TABLE_FIELD(field)                        \
  int get_window_ ## field (int l);               \
  void set_window_ ## field (int l, int v);
#include "window.h"
#undef FIELD
#undef TABLE_FIELD
void create_scratch_window (void);
int find_window (const char *name);
int popup_window (void);
void set_current_window (int wp);
void delete_window (int del_wp);
Point *window_pt (int wp);
void completion_scroll_up (void);
void completion_scroll_down (void);
bool window_top_visible (int wp);
bool window_bottom_visible (int wp);


/*
 * Declare external Zile functions.
 */
#define X(zile_name, c_name)                            \
  le F_ ## c_name (long uniarg, bool is_uniarg, le l);
#include "tbl_funcs.h"
#undef X
