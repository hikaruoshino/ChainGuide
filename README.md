# ChainGuide (v0.1.0)

**A skillchain guide for Windower 4 (FINAL FANTASY XI). It shows information only. It never uses a weapon skill for you.**

ChainGuide watches the weapon skills used on your target and shows, on a small HUD:

- the skillchain that is resonating, its property and level, and a colored bar;
- how long until the chain window opens, and how long it has left;
- which of **your own** weapon skills would continue the chain, and what chain each one would make.

You choose and press the weapon skill yourself. ChainGuide does not send any command to the game (no `input /ws`, no macros, no key presses).

> **v0.1.0: lightly tested.** It passes 30 checks in a simulated Windower environment, and I have used it in game (display, bar, dragging and the mouse wheel worked), but only briefly and on the Japanese client. I have not tested it on the English client, nor with every job and weapon. The timing numbers are guides, not exact. Please report anything that looks wrong.

## What it shows

```
=== ChainGuide ===
Chain: Fusion (Lv2)  step 1  by Ally5
GO!   6.4s left
Your weapon skills that chain:
> Savage Blade -> Light (Lv3)
```

(Sample output. The weapon skills listed depend on your job and weapon. Ones you cannot use right now are dimmed and marked `(TP)` or `(range)`.)

- **The bar** above the HUD takes the color of the chain's element (Fire red, Ice light blue, Wind green, Earth yellow, Thunder purple, Water blue, Light white, Dark violet). A chain with several elements (for example Fusion = Fire + Light) cycles through its colors.
- **WAIT / GO.** For the first 3 seconds or so after a weapon skill lands, the bar is solid and the HUD says WAIT: a weapon skill used now does not chain. Then the HUD says GO and the bar blinks, faster and faster as the window closes.
- **The list** has only your weapon skills that continue the current chain, best first (a weapon skill you can use right now comes first; then higher chain level). Ones you cannot use right now are dimmed, with the reason: `(TP)` not enough TP, `(range)` too far to reach.
- **All weapon types.** There is no weapon list inside the addon: your usable weapon skills and their chain properties are read from Windower's resources, so it works for every weapon type and job that has chainable weapon skills (weapon skills that do not chain, such as Starlight or Spirits Within, are not listed). I have only tried it in game with a few weapons so far.
- **Aeonic weapons:** if you wield an aeonic weapon, its Light/Darkness property is counted.
- **While there is no chain** it lists your weapon skills and their properties, to help you pick an opener.
- **After a Light -> Light or Darkness -> Darkness chain**, or a Radiance/Umbra chain, it says the chain is complete: nothing chains after that.

## Install

1. Put the `ChainGuide` folder in `Windower4/addons/`.
2. In game: `//lua l ChainGuide`. To load it automatically, add `lua l ChainGuide` to `Windower4/scripts/init.txt`.
3. `//cgd test` shows a sample chain for 12 seconds so you can check the display. **Drag the HUD with the mouse to move it, and scroll the mouse wheel over it to make it bigger or smaller** (the colored bar scales with it). The position and size are saved.

It needs only Windower's standard libraries (`config`, `texts`, `images`, `resources`, `packets`).

## Commands (`//cgd` or `//chainguide`)

| Command | What it does |
|---|---|
| `//cgd on` / `off` | Show / hide the guide |
| `//cgd combat [on\|off]` | Show it only while you are engaged or a chain is active (default on) |
| `//cgd rows <n>` | How many weapon skills to list (default 6) |
| `//cgd openers [on\|off]` | List your weapon skills while no chain is active (default on) |
| `//cgd bar [on\|off]` | The colored bar |
| `//cgd pos <x> <y>` / `//cgd size <n>` | HUD position / text size (you can also drag the HUD with the mouse, and scroll the mouse wheel over it to scale it) |
| `//cgd test` | Show a sample chain for 12 seconds |
| `//cgd status` | Current settings |

## How it works, and its limits

- The action packet (0x028) tells it which weapon skill was used on **your current target** and whether it made a skillchain. Weapon skills of anyone count (you, party members, trusts, other players), but only on the enemy you are targeting.
- Skillchain rules (which property chains into which) are from the BG-Wiki "Skillchain" page. Weapon skill properties come from Windower's resources. Nothing is read from or written to game memory.
- The time until the window opens (about 3 s; the value used is 3.3 s to be safe) and the window length (10 s, shorter after each chain, 4 s at the least) are the values I use in [OmniChain](https://github.com/hikaruoshino/OmniChain-EN). Lag and the exact timing in game differ a little, so treat them as guides.
- It does not draw a glow on the enemy. Windower cannot draw on the 3D model, so the colored bar and the HUD are the closest I can offer.
- Only moves on the enemy you are targeting are counted. A chain that happens while you are targeting another enemy is not picked up.
- A trust or monster move that has no chain property in Windower's resources is not recognized as an opener. Chainbound, pet skills and blood pacts are not covered yet.
- Using Windower is not permitted by the FFXI Terms of Service. I cannot guarantee that this addon is allowed or that it will not be detected. Use it at your own risk; the author accepts no responsibility for any consequences.

## Feedback

If you try it and something could be better, please tell me (open an issue on this repository, or reply on FFXIAH). I will fix what I can.

## License

MIT License. See `LICENSE`.
