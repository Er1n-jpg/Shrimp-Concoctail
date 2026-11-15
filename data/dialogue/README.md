# Customer dialogue

One text file per customer, named after the customer's id (`dumped_guy.txt` for
`data/customers/dumped_guy.tres`). Open it in any text editor.

## How a conversation is built

Every visit the game builds a fresh conversation:

1. one random **[opener]**
2. hint lines for **2 of the customer's 3 ingredients** (which 2 is random every visit,
   and so is which hint line), with a **[followup]** from the shrimp in between
3. one random **[closer]**, if the file has any

So the player only ever hears about two of the three. The recipe never changes, so
regulars can remember the third one.

## The format

```
# Lines starting with # are notes. The game ignores them.

[opener]
she left me.
shrimp: oof. what can i get you?
---
hey.
shrimp: rough night?

[bud_darks]
a beer as dark as my soul.
---
the darkest thing on tap.
```

- `[section]` starts a section. `[opener]`, `[followup]` and `[closer]` are the special
  ones; every other section is named after an **ingredient id** (the file names in
  `data/ingredients/`) and holds hint lines for that ingredient.
- `---` separates the options inside a section. The game picks one at random.
- An option can be several lines. Lines starting with `shrimp:` are said by the shrimp,
  every other line by the customer.
- Blank lines don't matter, use them for spacing.
- **Never name the ingredient in its hint.** "a beer as dark as my soul", not "Bud Darks".

## Optional setting

Put this above the first section to make one ingredient the customer's "usual": it's
never hinted, so the other two are hinted every visit and the player has to learn the
usual from experience.

```
signature: sugar
```

## Shared shrimp lines

`_shrimp.txt` has the shrimp's default **[followup]** lines ("anything else?"). A customer
file can have its own **[followup]** section to override them.

## Where the recipe lives

The 3 ingredients themselves are set in the customer's `.tres` file (`required`), along
with liked/hated ingredients, reviews and special rules. The Vibecoder (`hidden_recipe`)
gets a random recipe and no hints, so his file only needs openers.

**Exporting the game:** Godot doesn't pack `.txt` files by default. In the export preset,
add `*.txt` under Resources → "Filters to export non-resource files/folders", or the
customers will have nothing to say in the exported build.

When the game starts it prints a warning if something doesn't line up: a missing file,
an ingredient in the recipe with no hint section, or a section name that's a typo.
