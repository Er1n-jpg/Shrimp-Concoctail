class_name Palette
extends RefCounted
## The game's color palette (from the moodboard). Use these instead of raw colors.

const INK := Color("0d0402")         # near-black
const DARK_BROWN := Color("2d0f04")
const MAROON := Color("5b120d")
const RUST := Color("c53e22")
const ORANGE := Color("ea6a35")
const BUTTER := Color("fbef8e")      # pale yellow
const LIME := Color("cffb74")
const GREEN := Color("356921")
const SLATE := Color("5e534b")       # grey-brown
const TAUPE := Color("aba192")
const BLUSH := Color("f8d7d7")       # pale pink
const PINK := Color("f2a9a9")

# Derived UI colors
const CREAM := Color("fff8d8")       # BUTTER lightened, for speech bubbles / cards
const TEXT_DARK := DARK_BROWN
const TEXT_LIGHT := Color("fff8d8")
const MONEY := BUTTER
const GAIN := LIME
const LOSS := PINK

## Placeholder colors for customers without art (picked by id).
const CUSTOMER_COLORS := [ORANGE, RUST, PINK, TAUPE, GREEN, MAROON, SLATE]
