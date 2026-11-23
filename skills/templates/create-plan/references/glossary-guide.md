# Writing glossary entries

Loaded by `create-plan` in step 3, to draft entries when the project's glossary states no rules of its own or doesn't exist yet. Once a glossary states its rules, they win over these.

A glossary holds the agreed names for a product's domain concepts: what each one means, and the identifier the code uses for it. Plans, pull requests and code use each term exactly as written there. Match the format of the entries already in it.

## Entries

- **An entry is a definition, the code identifier with its file, and any names to avoid.** Point at the file, not a line: lines move.
- **One `###` heading per term, in alphabetical order**, so `grep '^### '` lists them.
- **Define a term once, in the narrowest glossary that owns it.** A word that means something else in another area says so in its entry, in each area's glossary.
- **A kind, state or other member of a set belongs to its concept's entry**, not an entry of its own.
- **Where the product's word and the code's differ**, the entry names both and says which to write.

```markdown
### Order

A customer's confirmed purchase, from checkout until it is delivered or cancelled. Its states are `OrderStatus`: placed, paid, shipped, delivered, cancelled. Code: `Order` ([src/orders/order.js](src/orders/order.js)). Avoid _purchase_ for the entity: in billing it means the card charge.
```

## Names not settled in the code

- **Rename pending:** a rename agreed before the code follows. The entry takes the agreed name as its heading and a `**Rename pending:**` line naming the identifiers still on the old name and the plan or ticket that renames them. The rename phase removes the line. Code and glossary disagreeing without that line is a bug in the glossary.
- **Planned terms:** a term defined before any code exists goes under `## Planned terms`, with its definition and no identifier. The phase that builds it moves it up to `## Terms`.
- **Open naming decisions:** two names for one concept that nobody has settled go under `## Open naming decisions`, with a proposal, until a plan settles them. The phase that writes the settled entry removes the item.

## When entries are written

The phase that introduces a concept's code writes its entry, in the same commit, so the glossary only describes code that exists. Backfills, updates and the rename's entry go in phase 1. Planning writes nothing to the glossary: the plan records the agreed entries under **Terms**, and each phase's to-do writes its own.

## Starting a glossary

When the project has none, the first plan that agrees on a term starts it at the path in step 2. Its **Terms** names that path as a new file, and the phase that writes the first entry creates it with this shape, holding only the terms the plan touches: the rest of the code gets entries as later plans reach it.

```markdown
# Glossary

The agreed names for <product>'s domain concepts: what each one means, and the identifier the code uses for it. Plans, pull requests and code use each term exactly as written here.

## Adding or changing a term

<The rules under "Entries" and "Names not settled in the code" above, one bullet each, and "When entries are written".>

## Terms

### <Term>

<Definition.> Code: `<Identifier>` ([path/to/file](path/to/file)).
```

The same phase adds a line to `AGENTS.md` (or `CLAUDE.md`) pointing at the glossary, so every session finds it.
