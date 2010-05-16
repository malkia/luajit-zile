FIELD(size_t, key) /* The key code (for every level except the root). */
FIELD(const char *, func) /* The function for this key (if a leaf node). */

/* Branch vector, number of items, max number of items. */
FIELD(Binding *, vec)
FIELD(size_t, vecnum)
FIELD(size_t, vecmax)
