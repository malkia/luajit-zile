/* Dynamically allocated strings
   Copyright (c) 2001-2004 Sandro Sigala.
   Copyright (c) 2003-2004 Reuben Thomas.
   All rights reserved.

   This file is part of Zile.

   Zile is free software; you can redistribute it and/or modify it under
   the terms of the GNU General Public License as published by the Free
   Software Foundation; either version 2, or (at your option) any later
   version.

   Zile is distributed in the hope that it will be useful, but WITHOUT ANY
   WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
   for more details.

   You should have received a copy of the GNU General Public License
   along with Zile; see the file COPYING.  If not, write to the Free
   Software Foundation, 59 Temple Place - Suite 330, Boston, MA
   02111-1307, USA.  */

/*	$Id: astr.c,v 1.17 2004/03/13 16:31:20 rrt Exp $	*/

#ifdef TEST
#undef NDEBUG
#endif

#include "config.h"

#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "astr.h"

#define ALLOCATION_CHUNK_SIZE	16

astr astr_new(void)
{
	astr as;
	as = (astr)xmalloc(sizeof *as);
	as->maxsize = ALLOCATION_CHUNK_SIZE;
	as->size = 0;
	as->text = (char *)xmalloc(as->maxsize + 1);
	memset(as->text, 0, as->maxsize + 1);
	return as;
}

static void astr_resize(astr as, size_t reqsize)
{
	assert(as != NULL);
	if (reqsize > as->maxsize) {
		as->maxsize = reqsize + ALLOCATION_CHUNK_SIZE;
		as->text = (char *)xrealloc(as->text, as->maxsize + 1);
        }
}

static int astr_pos(astr as, int pos)
{
	if (pos < 0)
		pos = as->size + pos;
        assert(pos >=0 && pos <= (int)as->size);
        return pos;
}

char *astr_char(const astr as, int pos)
{
        assert(as != NULL);
        pos = astr_pos(as, pos);
        return as->text + pos;
}

void astr_delete(astr as)
{
	assert(as != NULL);
	free(as->text);
	as->text = NULL;
	free(as);
}

static astr astr_assign_x(astr as, const char *s, size_t csize)
{
	astr_resize(as, csize);
	strcpy(as->text, s);
	as->size = csize;
	return as;
}

astr astr_assign(astr as, const astr src)
{
	assert(as != NULL && src != NULL);
	return astr_assign_x(as, src->text, src->size);
}

astr astr_assign_cstr(astr as, const char *s)
{
	assert(as != NULL && s != NULL);
	return astr_assign_x(as, s, strlen(s));
}

static astr astr_append_x(astr as, const char *s, size_t csize)
{
	astr_resize(as, as->size + csize);
	strcpy(as->text + as->size, s);
	as->size += csize;
	return as;
}

astr astr_append(astr as, const astr src)
{
	assert(as != NULL && src != NULL);
	return astr_append_x(as, src->text, src->size);
}

astr astr_append_cstr(astr as, const char *s)
{
	assert(as != NULL && s != NULL);
	return astr_append_x(as, s, strlen(s));
}

astr astr_append_char(astr as, int c)
{
	assert(as != NULL);
	astr_resize(as, as->size + 1);
	as->text[as->size] = c;
	as->text[++as->size] = '\0';

	return as;
}

astr astr_truncate(astr as, size_t size)
{
	assert(as != NULL);
	if (size < as->size) {
		as->size = size;
		as->text[size] = '\0';
	}

	return as;
}

astr astr_substr(const astr as, int pos, size_t size)
{
	astr dest;
	assert(as != NULL);
	dest = astr_new();
        pos = astr_pos(as, pos);

	if (as->size - pos < size)
		size = as->size - pos;
	if (size > 0) {
		astr_resize(dest, size);
		memcpy(dest->text, as->text + pos, size);
		dest->size = size;
	}
	return dest;
}

int astr_find(const astr as, const astr src)
{
	return astr_find_cstr(as, src->text);
}

int astr_find_cstr(const astr as, const char *s)
{
	char *sp;
	assert(as != NULL && s != NULL);
	sp = strstr(as->text, s);
	return (sp == NULL) ? -1 : sp - as->text;
}

int astr_rfind(const astr as, const astr src)
{
	return astr_rfind_cstr(as, src->text);
}

int astr_rfind_cstr(const astr as, const char *s)
{
	char *sp;
	assert(as != NULL && s != NULL);
        sp = strrstr(as->text, s);
	return (sp == NULL) ? -1 : sp - as->text;
}

static astr astr_replace_x(astr as, int pos, size_t size, const char *s, size_t csize)
{
	astr dest = astr_new();
        pos = astr_pos(as, pos);

	if (as->size - pos < size)
		size = as->size - pos;
	if (size > 0) {
		dest->size = as->size - size + csize;
		astr_resize(dest, dest->size);
		memcpy(dest->text, as->text, pos);
		memcpy(dest->text + pos, s, csize);
		strcpy(dest->text + pos + csize, as->text + pos + size);
	}
	free(as->text);
	*as = *dest;
	free(dest);
	return as;
}

astr astr_replace(astr as, int pos, size_t size, const astr src)
{
	assert(as != NULL && src != NULL);
	return astr_replace_x(as, pos, size, src->text, src->size);
}

astr astr_replace_cstr(astr as, int pos, size_t size, const char *s)
{
	assert(as != NULL && s != NULL);
	return astr_replace_x(as, pos, size, s, strlen(s));
}

astr astr_fgets(FILE *f)
{
	int c;
	astr as;

        if (feof(f))
                return NULL;
        as = astr_new();
	while ((c = fgetc(f)) != EOF && c != '\n')
		astr_append_char(as, c);
	return as;
}

astr astr_vafmt(astr as, const char *fmt, va_list ap)
{
	char *buf;
	vasprintf(&buf, fmt, ap);
	astr_append_cstr(as, buf);
	free(buf);
        return as;
}

astr astr_afmt(astr as, const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
        astr_vafmt(as, fmt, ap);
	va_end(ap);
	return as;
}

#ifdef TEST

void assert_eq(astr as, const char *s)
{
	if (!astr_eq_cstr(as, s))
		printf("test failed: \"%s\" != \"%s\"\n", as->text, s);
}

int main(void)
{
	astr as1, as2, as3;
	int i;

	as1 = astr_new();
	astr_assign_cstr(as1, "hello world");
	astr_append_char(as1, '!');
	assert_eq(as1, "hello world!");

	as3 = astr_substr(as1, 6, 5);
	assert_eq(as3, "world");

	as2 = astr_new();
	astr_assign_cstr(as2, "The ");
	astr_append(as2, as3);
	astr_append_char(as2, '.');
	assert_eq(as2, "The world.");

	astr_delete(as3);
	as3 = astr_substr(as1, -6, 5);
	assert_eq(as3, "world");

	astr_assign_cstr(as1, "12345");
	astr_delete(as2);

	astr_assign_cstr(as1, "12345");
	astr_delete(as2);
	as2 = astr_substr(as1, -2, 5);
	assert_eq(as2, "45");

	astr_assign_cstr(as1, "12345");
	astr_delete(as2);
	as2 = astr_substr(as1, -10, 5);
	assert_eq(as2, "12345");

	astr_assign_cstr(as1, "1234567");
	astr_replace_cstr(as1, -4, 2, "foo");
	assert_eq(as1, "123foo67");

	astr_assign_cstr(as1, "1234567");
	astr_replace_cstr(as1, 1, 3, "foo");
	assert_eq(as1, "1foo567");

	astr_assign_cstr(as1, "1234567");
	astr_replace_cstr(as1, -1, 5, "foo");
	assert_eq(as1, "123456foo");

	astr_assign_cstr(as1, "abc def de ab cd ab de fg");
	while ((i = astr_find_cstr(as1, "de")) >= 0)
	       astr_replace_cstr(as1, i, 2, "xxx");
	assert_eq(as1, "abc xxxf xxx ab cd ab xxx fg");

	astr_fmt(as1, "%s * %d = ", "5", 3);
	astr_afmt(as1, "%d", 15);
	assert_eq(as1, "5 * 3 = 15");

	printf("Input one string: ");
	fflush(stdout);
	astr_fgets(as1, stdin);
	printf("You wrote: \"%s\"\n", astr_cstr(as1));

	astr_delete(as1);
	astr_delete(as2);
	astr_delete(as3);
	printf("astr test successful.\n");

	return 0;
}

#endif /* TEST */
