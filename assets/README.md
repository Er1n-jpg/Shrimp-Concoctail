# Drop-in assets

Drop files here with these **exact names** and the game picks them up automatically. You don't need to edit any code or scene.
Until a file exists, the game shows a colored placeholder box in its place.

- Images: `.png`, `.webp`, `.jpg` or `.svg` (transparent PNG recommended)
- Sounds: `.ogg`, `.wav` or `.mp3`
- Sizes below are how big each image shows on the 1920×1080 screen. Make art at that size or 2× that size.
- If an image doesn't show up, focus the Godot editor once so it imports the new file.

## `ingredients/` (15 files, about 140×120, shown with the name + price under it)

| File | Ingredient |
|---|---|
| `white_monster.png` | White Monster |
| `diet_coke.png` | Diet Coke |
| `ringtone_ball.png` | Ringtone Ball |
| `bud_darks.png` | Bud Darks |
| `sugar.png` | Sugar |
| `wasabi.png` | Wasabi |
| `cheetos.png` | Cheetos |
| `mayo.png` | Mayo |
| `espresso.png` | Espresso (sits on the coffee machine) |
| `matcha.png` | Matcha (sits on the coffee machine) |
| `milk.png` | Milk |
| `protein_shake.png` | Protein Shake |
| `ice_cream.png` | Ice Cream |
| `soy_sauce.png` | Soy Sauce |
| `pickle_juice.png` | Pickle Juice |

The same images also show up small (76×76) on the order ticket.

## `customers/` (about 360×390, portrait facing right)

| File | Customer |
|---|---|
| `dumped_guy.png` | Dumped Guy |
| `project_not_working.png` | Project Not Working |
| `performative_guy.png` | Performative Guy |
| `linkedin_warrior.png` | LinkedIn Warrior |
| `vibecoder.png` | Vibecoder |
| `toronto_guy.png` | Toronto Guy |
| `hensen_juang.png` | Hensen Juang |

**Optional reaction swaps:** add `<name>_happy.png` (shown after a 4–5 star drink) and/or `<name>_mad.png` (shown after 1–2 stars), e.g. `toronto_guy_mad.png`.

## `ui/`

| File | What | Shown at |
|---|---|---|
| `background.png` | Bar / hackathon backdrop (stretched to fill) | 1920×1080 |
| `counter.png` | Counter top the ingredients sit on (stretched) | 1920×520, bottom of screen |
| `shrimp.png` | The shrimp bartender | 360×440, top right |
| `cup.png` | The cup. **Make the body see-through:** liquid layers draw behind it | 300×250 |
| `coffee_machine.png` | Coffee & matcha maker behind Espresso/Matcha (stretched) | 370×232 |
| `speech_bubble.png` | Order bubble + review card background (stretched) | 860×330 |
| `hud_bar.png` | Top stats bar background (stretched) | 1920×64 |

## `fonts/`

`main.ttf` (or `.otf`): used for all text in the game.

## `music/`

`theme.ogg`: loops in the background.

## `sfx/`

| File | Plays when |
|---|---|
| `pour.ogg` | You pour an ingredient |
| `brew_done.ogg` | Espresso/Matcha finishes brewing |
| `denied.ogg` | Can't pour (broke or cup full) |
| `trash.ogg` | You dump the cup |
| `serve.ogg` | You serve a drink |
| `cash.ogg` | Customer pays |
| `bad.ogg` | 1-star drink |
| `ask.ogg` | You ask the Vibecoder a clarifying question |
| `customer_in.ogg` | A new customer walks up |
| `inflation.ogg` | Prices go up |
| `game_over.ogg` | You go broke |

## Moving things around

Positions live in `scenes/main.tscn`. Open it in Godot and drag any node (ingredients are under `World/Shelf`) to line them up with your counter art.
