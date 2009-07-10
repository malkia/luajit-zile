TABLE_FIELD(branch) /* either data or a branch */
FIELD(const char *, string, data)
FIELD(int, integer, quoted)
TABLE_FIELD(next)   /* for the next in the list in the current parenlevel */
