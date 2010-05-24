/* Next undo delta in list. */
TABLE_FIELD(next)

/* The type of undo delta. */
FIELD(int, integer, type)

/* Location of the undo delta. Stored as a numeric position because
   line pointers can change. */
FIELD(size_t, integer, n)
FIELD(size_t, integer, o)

/* Flag indicating that reverting this undo leaves the buffer
   in an unchanged state. */
FIELD(bool, boolean, unchanged)

/* The block to insert. */
FIELD(astr, lightuserdata, text)
FIELD(size_t, integer, osize)		/* Original size. */
FIELD(size_t, integer, size)		/* New block size. */
