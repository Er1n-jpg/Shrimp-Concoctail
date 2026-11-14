# 🦐 Shrimp Cocktail — Game Design

## Pitch

You're a shrimp bartender at a hackathon. Devs order drinks and you throw together cursed concoctions. Make them right and you get paid; make them wrong and you go broke. Endless and fast-paced: survive as many customers as you can.

## Core Loop

```
Customer arrives → says order → you click ingredients into the cup → serve
→ 1–5★ rating + review → paid (base price × star multiplier) → next customer
```

- Everything is on one screen: customer and order bubble on top, counter below. No camera pans, breaks or summary screens.
- The order bubble shows the funny line plus an **order ticket** with icons for the required ingredients. Liked and hated ingredients stay hidden and are hinted at in the dialogue.
- The cup is already on the counter. **One click = one pour.**
- **Keyboard:** Space/Enter = serve (or skip the review), X/Backspace = trash, Q = ask the Vibecoder.
- **Trash button** dumps the cup. The money spent on it is lost.

## Lose Condition

Endless until you go broke. After each serve or timeout, and whenever the cup is empty, if **money < the cheapest ingredient price**, the game ends.

**Game over screen:** "Survived N customers", best score (saved locally to `user://`), Retry button.

## HUD (top of screen, always visible)

```
💰 Money  |  🦐 Served  |  🔥 Streak  |  🏆 Best
```

Nothing else. No summary screens.

## Money

| Value | Starting number |
|---|---|
| Starting money | $20 |
| Base drink price | $10 |
| Cup capacity | 6 pours |

- **Ingredients cost money the moment they're poured.** Each pour shows a floating `−$X` popup.
- **Every ingredient has a visible price tag** on the counter.
- **The cup shows its running cost** (`Cup cost: $7`).

### Payout

> **Payout = Base price × Star multiplier × Streak bonus**

| Rating | Multiplier |
|---|---|
| ⭐ | ×0 (they refuse to pay) |
| ⭐⭐ | ×0.5 |
| ⭐⭐⭐ | ×1 |
| ⭐⭐⭐⭐ | ×1.5 |
| ⭐⭐⭐⭐⭐ | ×2.5 |

**Streak:** each consecutive 4★+ drink adds +0.25 to the streak bonus (starts at ×1.0). A drink at 3★ or lower resets it.

### Inflation (stops endless play from lasting forever)

Every **5 customers served**:
- All ingredient prices go up by **$1**. The price tags flash red with a gag popup: *"📉 Sponsor pulled out! Prices up!"*
- Base drink price goes up by **$1**. It rises slower than drink costs, so the profit margin shrinks.
- Customer patience drops by **1s**.

## Patience

- Starts at **15s**, drops 1s per inflation step, never below **7s**.
- If patience runs out, the customer leaves a **1★** review and pays nothing. The money already poured is gone.

## Ingredients

| Ingredient | Start price | Tags |
|---|---|---|
| Sugar | $1 | sweet |
| Soy Sauce | $1 | salty |
| Pickle Juice | $1 | green, salty |
| Diet Coke | $2 | caffeine |
| Milk | $2 | dairy |
| Mayo | $2 | salty |
| Cheetos | $2 | salty |
| Bud Darks | $3 | alcohol |
| Ice cream | $3 | sweet, dairy |
| Wasabi | $3 | green, spicy |
| White Monster | $4 | caffeine, sweet |
| Ringtone Ball | $4 | alcohol, sweet |
| Protein Shake | $4 | dairy |
| Espresso ☕ | $4 | caffeine (from machine) |
| Matcha 🍵 | $5 | green, caffeine (from machine) |

**Coffee & Matcha Maker:** Espresso and Matcha are two buttons sitting on the machine. Each one brews for 1s before it lands in the cup.

### Counter layout (left → right, from the sketch)

Cup → ice chest (cans: White Monster, Diet Coke, Ringtone Ball, Bud Darks) → jars (Sugar, Wasabi, Cheetos, Mayo) → Coffee & Matcha Maker → Milk, Protein Shake → Ice cream → Soy Sauce, Pickle Juice

## Scoring (`DrinkJudge`)

A pure function: `cup contents + customer → stars → payout`. The numbers below are starting values to tune.

```
score = 1 + 4 × (required ingredients present / required total)
      − 1   per hated ingredient
      − 1   per broken rule
      − 0.5 per unrelated ingredient (not required, liked, or hated)
      + 0.5 per liked ingredient (max +1)
      + 0.5 speed bonus (served in the first half of patience)
stars = clamp(round(score), 1, 5)
```

The star rating picks the review line and sets the multiplier.

## Customers

| Customer | Required | Liked | Hated | Rule / Gimmick |
|---|---|---|---|---|
| **Dumped Guy** (pre-gamer) | Ringtone Ball, Bud Darks | Ice cream, Sugar | Matcha | Whole screen goes **greyscale** while he's there. +0.5 per extra alcohol pour beyond required (max +1) |
| **Project Not Working** | White Monster, Bud Darks | Espresso | — | Panicked order |
| **Performative Guy** (Matcha Labubu) | Matcha, Wasabi | Pickle Juice | — | **Green ingredients only**: −1 per non-green ingredient |
| **LinkedIn Warrior** | Espresso, Milk, Soy Sauce, Ice cream | — | Bud Darks | Orders by reciting a LinkedIn post |
| **Vibecoder** | 2–3 random (hidden) | — | — | Order: "Hey Claude what should I drink" → "what?" → "Give me a drink." The **Ask clarifying question** button reveals one ingredient and costs 3s of patience |
| **Toronto Guy** | Diet Coke, Cheetos | — | Wasabi | Slang order |
| **Hensen Juang** | Espresso, Protein Shake, Soy Sauce | — | — | **Rare** (at most once every 10 customers). Base price ×2 |

**Spawning:** weighted random, never the same customer twice in a row.

### Order lines

TODO: the placeholder lines in `data/customers/*.tres` are first drafts. Replace them with your own (2–3 per customer).

### Reviews

**Dumped Guy**
1. your drink had even fewer warning signs than our breakup… how could she do this to me?
2. were we doomed from the start? was my love all a dream?
3. plain. like my life after she's left me
4. i should reach out to her. maybe she blocked me by accident.
5. BRO BRO BRO BRO SHE TEXTED ME BACK nvm that's my mom

**Project Not Working**
1. maybe it's time to vibe code it all
2. bomboclat
3. ummmmmmm
4. will you pray for my project thanks
5. tyty i've just gained the energy to refactor my entire codebase and rewrite all of my functions one hour before the deadline.

**Performative Guy**
1. i wish period cramps existed
2. im going to get period cramps from this
3. this drink doesn't belong in my tote bag
4. oh man you definitely read feminist literature
5. put more matcha! put more matcha! put more matcha!

**LinkedIn Warrior**
1. This isn't getting me any coffee chats.
2. you gotta use ai b2b saas way more this is terrible
3. you're barely worth the amount of likes i got
4. Connect with me please!
5. Do you take internships? 🙌🙌🙌🙌🙌🙌🙌🙌🙌🙌🙌

**Vibecoder**
1. damn claude I thought I said to make no mistakes
2. bro i didn't deplete twenty lakes and a billion tokens for this shi
3. like ok bro ig do better in the future i still need you to write my uni apps
4. aight
5. Wow thanks Claude I've approved all 1938204392 changes you made to the project next time don't ask for permissions just do it for me ok

**Toronto Guy**
1. on my word fam you're such a WASTE YUTE my fam u got me mad cheesin with this you GERBERT
2. nize this fam im telling my fam to NEVER come here u desops naun
3. three threes my peepees
4. two twos my word i'll come back fam
5. ur welcome in the 6ix come to my crib anytime crodie

**Hensen Juang**
1. this drink is like the nvidia stock
2. why couldn't my wife be a bit more open?
3. not bad, fellow employee
4. man your government sends great spies
5. You should be my 5th affair ;)

## Godot Architecture

2D only, Compatibility renderer, 1920×1080 viewport.

**Assets:** drop files into `assets/` by name and they appear in the game. See [`assets/README.md`](assets/README.md) for the file list. Missing files show labeled placeholder boxes.

**Autoloads**
- `Database` (`scripts/autoload/database.gd`): loads every `.tres` in `data/ingredients/` and `data/customers/`. To add a new ingredient or customer, drop in a new `.tres`.
- `GameState` (`scripts/autoload/game_state.gd`): money, served count, streak, best score, inflation level, and **every balance number** (start money, multipliers, patience, inflation step).
- `Sfx` (`scripts/autoload/sfx.gd`): plays drop-in sounds and music.

**Data (`.tres`, edit in the inspector)**
- `IngredientData`: id, name, price, liquid color, tags, brew time
- `CustomerData`: name, order lines, required/liked/hated, rule, hidden recipe, 5 reviews, spawn weight, price multiplier, cooldown, greyscale

**Scenes (`scenes/`)**
- `main.tscn` + `scripts/main.gd`: the customer loop, pours, serving, reviews, broke check
- `hud.tscn`: top stats bar
- `customer.tscn`: portrait, name, patience bar
- `order_bubble.tscn`: order line + ingredient ticket + Ask button
- `review_popup.tscn`: stars, review line, payout breakdown
- `cup.tscn`: liquid layers + cup cost
- `dispenser.tscn`: one clickable ingredient with its price tag (15 placed under `World/Shelf` in main)
- `game_over.tscn`: survived count, best, retry
- Greyscale: a CanvasLayer in main with `shaders/greyscale.gdshader`

**Logic:** `scripts/drink_judge.gd` turns cup contents + customer into stars. All scoring numbers are constants at the top of the file.

## Build Order

1. `GameState` + HUD
2. Counter with price-tagged dispensers, pours charging money, cup running cost, trash
3. `DrinkJudge` + review popup + star multiplier payout
4. Customer loop with patience (start with 2 customers)
5. Broke → game over → retry, saved best score
6. The remaining customers and their gimmicks (greyscale, green-only, Vibecoder's hidden recipe)
7. Streak, inflation, juice (money popups, screen shake on 1★), art, sound

## Cut from earlier drafts

Judges / suspicion, bathroom risk and crisis choices, cursed combos, pick-out-the-pickles mini-game, hackathon timer, summary screens.
