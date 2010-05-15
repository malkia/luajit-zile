/* Next undo delta in list. */
FIELD(Undo *, next)

/* The type of undo delta. */
FIELD(int, type)

/* Where the undo delta need to be applied.
   Warning!: Do not use the p field of pt. */
FIELD(int, pt)

/* Flag indicating that reverting this undo leaves the buffer
   in an unchanged state. */
FIELD(bool, unchanged)

/* The block to insert. */
FIELD(astr, text)
FIELD(size_t, osize)		/* Original size. */
FIELD(size_t, size)		/* New block size. */
