# Drop-in assets

Drop files here with these **exact names** and the game picks them up automatically. You don't need to edit any code or scene.
Until a file exists, the game shows a colored placeholder box in its place.

- Images: `.png`, `.webp`, `.jpg` or `.svg` (transparent PNG recommended). Everything uses pixel-sharp filtering.
- Sounds: `.ogg`, `.wav` or `.mp3`
- Sizes below are how big each image shows on the 1920×1080 screen. 64×64 pixel art works great for items and characters.
- If an image doesn't show up, focus the Godot editor once so it imports the new file.

## `ingredients/` (64×64 art, shown at 2× = 128px with name + price under it)

| File | Ingredient |
|---|---|
| `white_monster.png` | White Monster |
| `diet_coke.png` | Diet Coke |
| `ringtone_ball.png` | Ringtone Ball |
| `bud_darks.png` | Bud Darks |
| `sugar.png` | Sugar |
| `wasabi.png` | Wasabi |
| `mayo.png` | Mayo |
| `espresso.png` | Espresso spoon (drag it into the coffee machine) |
| `matcha.png` | Matcha spoon (drag it into the coffee machine) |
| `milk.png` | Milk |
| `protein_shake.png` | Protein Shake |
| `ice_cream.png` | Ice Cream |
| `soy_sauce.png` | Soy Sauce |
| `pickle_juice.png` | Pickle Juice |

The same images show up at 64×64 in the cup tray (what you've poured).

## `customers/` (64×64 art, shown at 8× = 512px in the talk view)

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

## `cup/` (64×64 art, shown at 4× = 256px in the cup tray)

| File | When |
|---|---|
| `stack.png` | The stack of cups on the bar you grab from (drawn with a white outline) |
| `empty.png` | Cup grabbed, nothing in it |
| `35.png` | 1–2 pours |
| `65.png` | 3–4 pours |
| `full.png` | 5–6 pours |
| `<level>_sugar_rim.png` | Sugar in the drink, e.g. `full_sugar_rim.png` (falls back to the plain level if missing) |
| `shaker_lid.png` | Optional: the cap shown while shaking (about 36×18 art px) |

**Draw the liquid in neutral grey** (like the current cups). The game tints any grey pixel to the drink's color and keeps your shading. The outline and white glass stay as drawn.

## `ui/`

| File | What | Shown at |
|---|---|---|
| `background.png` | Talk-view backdrop (stretched). Until then, a code-drawn back bar with shelves, lamps and a neon sign | 1920×1080 |
| `counter.png` | Talk-view counter in front of the shrimp (stretched). **The shrimp stands behind it, so the top edge must be solid** | 1920×320, bottom of screen |
| `bar_background.png` | Bar-view back wall (stretched). Until then, code-drawn shelves and lamps | 3840×1080 (2 screens wide, scrolls) |
| `bar_counter.png` | Bar-view counter the ingredients stand on (stretched) | 3840×440 |
| `shrimp.png` | The shrimp bartender | 512×512, right side, bottom behind the counter |
| `coffee_machine.png` | Coffee & matcha maker, between the two spoons. Shown at 4×; if the art changes, the group head / screen / drip tray spots are constants at the top of `scripts/ui/coffee_machine.gd` | 64×64 |
| `logo.png` | Game logo on the sign in the top-left of the talk view (replaces the neon "SHRIMP COCKTAIL" text). Drawn at the biggest whole-number scale that fits, currently 3× | 128×64 |
| `speech_bubble.png` | Customer's dialogue bubble + review card. 9-sliced at 5× (corners + tail stay crisp, edges stretch); tail goes bottom-left toward the customer | 860×330 (172×66 art px) |
| `shrimp_box.png` | Shrimp's dialogue box + the order ticket. 9-sliced at 5× | 860×240 and 470×215 |
| `hud_bar.png` | Top stats bar background (stretched) | 1920×64 |

## `fonts/`

`main.ttf` (or `.otf`): used for all text in the game. Right now it's **Jersey 10** (free, SIL Open Font License, see `OFL.txt`). Replace both files to swap fonts.

## `music/`

`theme.ogg`: loops in the background.

## `sfx/`

| File | Plays when |
|---|---|
| `customer_in.ogg` | A new customer walks up |
| `talk.ogg` / `talk_shrimp.ogg` | A customer / shrimp line appears |
| `whoosh.ogg` | Camera pans between the talk view and the bar |
| `cup.ogg` | You grab a cup |
| `pour.ogg` | You pour an ingredient |
| `spoon.ogg` | You pick up the Espresso/Matcha spoon |
| `brew.ogg` | The spoon locks into the machine and it starts brewing |
| `brew_done.ogg` | Espresso/Matcha finishes brewing |
| `shake.ogg` / `shake_done.ogg` | You start shaking / the drink is mixed |
| `denied.ogg` | Can't pour (no cup, broke, or cup full) |
| `trash.ogg` | You dump the cup |
| `serve.ogg` | You serve a drink |
| `cash.ogg` | Customer pays |
| `bad.ogg` | 1-star drink |
| `ask.ogg` | You ask the Vibecoder a clarifying question |
| `inflation.ogg` | Prices go up |
| `game_over.ogg` | You go broke |

## Colors

The palette lives in `scripts/palette.gd`; button and panel styles live in `ui/theme.tres`.

## Moving things around

Positions live in `scenes/main.tscn`. Open it in Godot and drag nodes around:
the talk view is `World/TalkView`, the bar is `World/BarView` (ingredients are under `World/BarView/Shelf`).
