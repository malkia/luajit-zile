FIELD(struct le *, branch) /* either data or a branch */
FIELD(char *, data)
FIELD(int, quoted)
FIELD(struct le *, next)   /* for the next in the list in the current parenlevel */
