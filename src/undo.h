/* Next undo delta in list. */
TABLE_FIELD(next)

/* The type of undo delta. */
FIELD(int, integer, type)

/* Where the undo delta need to be applied.
   Warning!: Do not use the p field of pt. */
TABLE_FIELD(pt)

/* Flag indicating that reverting this undo leaves the buffer
   in an unchanged state. */
FIELD(bool, boolean, unchanged)

/* The block to insert. */
FIELD(astr, lightuserdata, text)
FIELD(size_t, integer, osize)		/* Original size. */
FIELD(size_t, integer, size)		/* New block size. */
