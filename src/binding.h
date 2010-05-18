FIELD(size_t, integer, key) /* The key code (for every level except the root). */
FIELD(const char *, string, func) /* The function for this key (if a leaf node). */

/* Branch vector, number of items, max number of items. */
TABLE_FIELD(vec)
