# 03 — Characters (story + exact build specs)

All human characters are **R15 Roblox avatars** built from the default body (via `HumanoidDescription`), recolored with **BodyColors**, and dressed with **part-built gear** (welded Parts and Accessories made of Parts). No uploaded clothing images. See `08_rigs_and_animation.md` §1 for the build method and `06_art_direction.md` for the palette.

**Default proportions** (HumanoidDescription scales): Height 1.0, Width 1.0, Depth 1.0, Head 1.0, BodyType 0, Proportion 0. Exceptions are listed per character. The default face decal is used for everyone (the classic Roblox look).

**Uniform system** (shared by all military characters):
- **Pilot suit:** Torso and arms colored with the suit color. Legs = suit color. Feet = boot color (`#1E2125`). Hands = glove color (`#2A2D31`).
- **Part-built pilot harness**, welded to UpperTorso: two shoulder straps (0.25 × 2.2 × 0.15 studs, `#1E2125`), a chest plate (1.4 × 0.9 × 0.25, `#4A5A6A`, Metal), a collar ring (Cylinder 0.35 × 1.3 × 1.3, rotated, `#2A2D31`), a belt (2.05 × 0.25 × 1.05 around LowerTorso, `#1E2125`) with buckle (0.35 × 0.25 × 0.1 Neon `#E8A33D`).
- **Rank tabs:** on the left upper arm, small Neon bars (0.3 × 0.08 × 0.05), `#E8A33D`. Pilot Officer = 1 bar, Lieutenant = 2, Captain = 3, Commander = 1 chevron made from 2 wedges.
- **Division patch:** on the right upper arm, 0.5 × 0.5 × 0.05 square `#4A5A6A` with an amber 0.3 × 0.08 bar.
- **Officer uniform** (Vale, Rhein): torso `#3B4A5A`, legs `#2B3440`, long-coat skirt built from 2 thin parts (1.0 × 1.4 × 0.1) hanging from the back and sides of LowerTorso, shoulder boards (0.6 × 0.08 × 0.4).
- **Technician:** torso `#5E6B48` (olive coverall) with high-vis strips (0.06-thick Neon `#E8B923` bands, at 70% transparency so they don't glow too hard), tool belt with 3 pouch blocks.
- **Science / medical:** lab coat built from parts: torso white `#E6E8EA`, a coat-tail skirt to mid-thigh, and lapels as 2 thin wedges.

**Hair** is built from Parts welded to the Head, in the hair color, SmoothPlastic. Each style is defined as part blocks relative to the head's center (head ≈ 1.2 × 1.2 × 1.2 studs on default R15). Keep every hairstyle at 6–14 parts.

---

## Elias Veyne — protagonist (player character, `StarterCharacter`)

- **Age:** 18. **Role:** newly commissioned Pilot Officer, Ember-2, pilot of **Vanguard Unit 02**.
- **Origin:** Corrow. Mother **Ilse Veyne**, civilian infrastructure maintenance. Father **Captain Tobias Veyne**, 9th Frontier Defense Unit, officially died at the **Lowmarch Breach, 2181**. No remains. The report is brief and classified.
- **Personality:** observant, determined, compassionate, occasionally stubborn. Dry humor when nervous.
- **Central flaw:** believes that if he works hard enough and follows the right principles, he can protect everyone who depends on him. This makes him capable, and also makes him easy to manipulate.
- **Motivation (start):** protect people; spare other families the uncertainty his family lived with.
- **Habits** (show, don't tell): taps the cockpit hatch twice; keeps his father's old unit patch in his locker; counts steps when anxious (mention it at most once per chapter).
- **Arc:** from simple right and wrong → institutions can protect and harm at once → "the truth doesn't automatically make things better" → choosing what future deserves protecting.
- **Speech:** short sentences, sincere, asks questions, rarely swears ("ash it" at most).

**Build:**
- Skin `#C69C7A`. Height scale **1.02**.
- Pilot suit `#2B2F36` with amber piping: thin Neon strips (0.06 wide, 30% transparency) down the outer arms and legs, `#E07A1F`.
- **Hair: "short messy crop," dark brown `#3A2A1E`.** Base cap 1.25 × 0.35 × 1.25 on top (Y +0.62). Three tufts 0.4 × 0.3 × 0.5 angled 10–20° on the top-front. Two side pieces 0.15 × 0.5 × 1.0 at X ±0.62. Back piece 1.2 × 0.6 × 0.15 at Z +0.62.
- **Gear:** standard pilot harness. A small amber squad tag on the chest plate: SurfaceGui text "EMBER-2", Michroma, `#E8A33D`.
- **Signature item:** his father's **9th FDU patch**. As a prop in his locker and on his room desk: a 0.5 × 0.5 × 0.05 square `#5B4A3A` with a white "9" (SurfaceGui).

## Mara Solen — closest companion

- **Age:** 18. **Role:** Pilot Officer, **Ember-1** (squad lead), pilot of **Vanguard Unit 01**.
- **Background:** grew up in Corrow three streets from Elias. Her family suffered through Directorate resource shortages (a winter when her younger brother **Teo** got sick and the medicine convoy was rerouted). She understands why people trust the military, but she never fully has.
- **Why she joined:** believes the system can be improved from inside, and she intends to rise high enough to do it.
- **Personality:** direct, competitive, perceptive, impatient with authority that won't explain itself. Sees hesitation as weakness. Teases Elias about his "hatch ritual."
- **Relationship with Elias:** years of shared history, shown through small details (inside jokes, the "Corrow rooftop" where they watched convoys as kids, a running bet on simulator scores: **she's ahead 41 to 39**). They disagree. She's frustrated when he takes risks, and he's frustrated when she does.
- **Rule:** never only a motivator for Elias. She acts on her own judgment, sometimes against his.
- **Speech:** fast, teasing, precise under pressure; calls him **"Veyne"** when annoyed and **"Eli"** when it's serious.

**Build:**
- Skin `#8D5A3B`. Height scale **0.98**.
- Pilot suit `#2B2F36` with red piping `#C8483C`. Chest tag "EMBER-1".
- **Hair: "high tight ponytail," black `#15110F`.** Base cap 1.25 × 0.3 × 1.25. Hairline band 1.27 × 0.2 × 0.2 at the front. Tie ring (Cylinder 0.25 × 0.35 × 0.35 Neon `#C8483C`) at the back-top (Y +0.45, Z +0.55). Ponytail chain: 3 parts (0.35 × 0.6 × 0.35, then 0.3 × 0.6 × 0.3, then 0.22 × 0.5 × 0.22) hanging back and down from the tie, each tilted 15° more. Welded to Head (no physics). The procedural idle sway rotates the ponytail ±4°.
- **Gear:** standard harness plus fingerless-glove look (hands `#8D5A3B`, with a wrist band 0.3 × 0.15 × 0.3 `#2A2D31` on each LowerArm end).

## Commander Adrian Vale — division commander

- **Age:** 46. **Role:** Commander of the Third Frontier Frame Division; trains new pilots.
- **Belief:** stability is the precondition for survival. He has seen what failure costs. Civilian protection is his highest duty.
- **Not secretly evil.** He wants his soldiers to live.
- **Flaw:** he has accepted classified decisions he doesn't understand for years, and he slowly confuses *protecting people* with *deciding what they may know*.
- **With Elias:** he respects him; he served alongside Tobias Veyne once (he will reveal this in Ch2).
- **Speech:** measured, clipped, formal. Says "Pilot" instead of first names. One dry joke per chapter, maximum.

**Build:**
- Skin `#B7835F`. Height scale **1.06**, Width 1.05.
- Officer uniform. Rank chevron.
- **Hair: "short grey sidepart," `#8F8A84`.** Cap 1.24 × 0.25 × 1.24, a part-line groove made by two slightly offset top pieces, sides 0.12 × 0.35. **Beard stubble:** a 1.0 × 0.35 × 0.1 jaw piece in `#8F8A84` at 30% transparency on the front-lower head.
- **Gear:** a datapad held in the left hand (0.6 × 0.8 × 0.08, screen Neon `#E8A33D` at 60% transparency), welded to LeftHand.

## Dr. Sera Voss — biological researcher

- **Age:** 34. **Role:** Science Division researcher studying Frame cores and Titan physiology.
- **Personality:** intelligent, reserved, uncomfortable with the secrecy around her work. Kind in small practical ways (warm drinks, honest timelines).
- **What she knows:** discrepancies between the official scientific record and her own data. She knows findings are being suppressed. She doesn't know the whole truth.
- **Dilemma:** protect Elias by keeping him uninformed, or trust him with evidence that could end her career.
- **Speech:** precise, uses numbers, avoids speculation out loud. When she does speculate, she says "Hypothetically."

**Build:**
- Skin `#E1B899`. Height scale **0.97**.
- Lab coat build: inner shirt torso `#6C7A89`, legs `#3B3F45`.
- **Hair: "low bun," auburn `#7A3E22`.** Cap 1.25 × 0.3 × 1.25. Bun = Ball 0.6 at the back (Y −0.1, Z +0.65). Two thin strands (0.12 × 0.6 × 0.1) framing the face.
- **Gear:** glasses (two 0.32 × 0.22 × 0.05 thin frames in `#1E2125`, with Glass lenses at 70% transparency, plus a bridge bar), and an ID badge on the coat (0.3 × 0.4 × 0.03 white with an amber stripe).

## Commander Noah Rhein — senior operations commander

- **Age:** 39. **Role:** oversees strategic defense operations. Secretly heads **Project ECHO**.
- **Belief:** humanity must aggressively understand and control the phenomenon. Secrecy is necessary. Sacrificing individuals is acceptable to prevent catastrophe.
- **Not cruel for its own sake.** He believes a threat is coming that humanity can't survive without radical action (he knows about the Bloom).
- **Speech:** calm, warm on the surface, uses first names to disarm. Never raises his voice.

**Build:**
- Skin `#D3A685`. Height scale **1.04**.
- Officer uniform, but black-grey `#24282E` with **thin silver** trims (`#AEB6BF`, Metal) instead of amber. Rank chevron in silver.
- **Hair: "slicked back," black `#1C1A19`.** Cap 1.24 × 0.35 × 1.30 slightly extended back, with a smooth wedge on top angled back 8°.
- **Gear:** black gloves (hands `#1E2125`). A small silver pin with an ECHO symbol on the collar: 3 concentric thin rings (Cylinders 0.05 thick). This is a clue: the same symbol appears on the research rover and the data spindle.

## Orin — the Shifter (human form; Titan form = "the Watcher")

- **Apparent age:** early twenties. **Pronouns:** they/them.
- **Role:** mysterious Titan Shifter of the Remnants. **First appears in Titan form in Ch1** (the Watcher, unidentified). Human form appears in Ch3.
- **Goal:** reach the Site Kestrel archives, which they believe hold the means to stop the Bloom.
- **Personality:** quiet, observant, hard to read; understands military procedure unnervingly well (they were in ECHO custody for 3 years). Doesn't trust Elias, and doesn't think the military can be reformed through ordinary channels, but isn't sure destroying it would save anyone.
- **Central tension:** wanting the truth vs. fearing what it will unleash.
- **Rule:** stay mysterious through Act I. Never explain their history on first appearance.

**Build (human form, Ch3+):**
- Skin `#A8836A`. Height scale 1.0, Width 0.9.
- **Clothing:** grey-green scavenger jacket (torso `#4E5A4F`), dark trousers `#2F3330`, a wrapped scarf (3 parts around the neck, `#6B6455`).
- **Hair: "shaggy medium," ash-blond `#B9AE96`.** 10 parts: cap plus layered fringe pieces falling over the eyes.
- **Tell:** faint cyan vein lines on the left forearm. These are thin Neon `#7FE3F0` strips at 80% transparency, made visible only when emotional, toggled by script.

---

## Supporting cast (Chapter 1)

| Name | Role | Build summary | Personality / use |
|---|---|---|---|
| **Corporal Imani Okafor** | Halden Overwatch radio operator. Voice only in missions; seen at an Ops Hall console | Skin `#5C3A26`, technician-style olive with a headset (a 0.15-thick arc of 3 parts plus a mic boom) | Professional, warm, steady. "Overwatch copies." |
| **Chief Technician Hollis Brandt** | Hangar chief | Skin `#C79A7E`, height 1.0, width 1.15, technician coverall, bald with a grey beard (beard: 1.1 × 0.45 × 0.3 front block plus 2 side blocks, `#9B958C`), welding goggles pushed up on his forehead | Gruff, loves the machines, calls Frames "she." Ambient lines plus one Ch1 exchange |
| **Sergeant Dace Morrow** | Quartermaster at the Equipment Terminal | Skin `#9E6B4A`, technician olive with an armored vest | Bored, sarcastic, secretly kind. Runs the upgrade terminal (Phase 6) |
| **Pilot Tamsin Rook** | Fellow pilot (another squad), quarters corridor | Skin `#F0C8A8`, pilot suit with green piping `#5FAF6A`, red bob hair `#A8432A` | Friendly rival. One optional conversation; foreshadows "core-sick" |
| **Technician Pell** | Bay 3 welder (ambient) | Coverall, welding mask (a 1.0 × 1.0 × 0.3 dark block over the face) | Ambient only |
| **Ops officers ×6** | Ops Hall consoles | Officer uniforms, varied skin tones from the palette | Ambient barks only |
| **Technicians ×6** | Hangar ambient | Technician coveralls | Walk routes, inspect machines |
| **Lt. Hana Ferris** | Outpost 07 commander (absent; found in logs) | — | Her logs are evidence items |
| **Ilse Veyne** | Elias's mother (Ch2+) | Skin `#D8A982`, civilian maintenance coat `#7A6A55` | Ch2+ |
| **Captain Tobias Veyne** | Elias's father (missing) | Seen only in the photo prop and later chapters | The voice in the anomaly |

**Skin tone list** (for ambient NPCs; rotate so crowds are diverse): `#F0C8A8`, `#E1B899`, `#D3A685`, `#C69C7A`, `#B7835F`, `#9E6B4A`, `#8D5A3B`, `#5C3A26`, `#3F2A1E`.

---

## Voice and dialogue style guide

- People talk like people: contractions, interruptions, half-sentences under stress. No speeches unless it's a speech.
- **Maximum line length: 120 characters** (one subtitle line; two if necessary). Split longer thoughts.
- Humor is allowed even in dark scenes. Not every scene foreshadows doom.
- Exposition comes through conflict or task ("Why'd they bypass the fuel depot?"), not lectures.
- Never name the Lattice, Resonants or ECHO in Chapter 1 dialogue. Only the ECHO **symbol** and the label "ECHO-9" appear, as clues.
