# Release icon curation evidence

- Coverage: **132 / 132** new choices (M09–M24, F05–F36, A013–A096).
- Actual PNG artwork: **126 distinct files**. No generated replacement vectors or bitmap modifications.
- Validation: all 132 mappings resolve, every file decoded successfully as PNG with Pillow, and every destination is byte-identical to its catalogued original. SHA-256 checked against `assets/catalog.json` for every record.
- API: `godot/data/release_icons.json` contains `icons[runtimeId] = "assets/release-icons/<basename>.png"`; UI prefixes `res://`. The `sources` array contains canonical ID, design name, original file/URL/display name, SHA-256, git blob SHA, reason and match type.
- Original first 8 spells, 4 fusions and 12 artifacts are excluded from the map and their content icon fields were not changed.
- Reproducible packaging: `python3 scripts/build-release-icons.py`. Uses standard-library code, no new dependency.

## Selection basis

Inspected actual contact sheets of all 58 magic, 153 artifact and 30 passive PNGs before mapping. Inspected the selected fire, frost-needle, well, dagger, seed, glyph, mine, wall, bell, talisman, healing, rock, coil, chalice, bottle and compass symbols again at readable size. Selection is based on visual form and mechanic, not a hash/modulo assignment. The reused source display names do not assert identity with new GDD designs.

## Deliberate motif reuse

- `shadowcape.png`: M21, A039. Same literal object or mechanic motif (bell, dark cloth, conductive strands, chalice or potion vessel).
- `deathbell.png`: M23, A021, A094. Same literal object or mechanic motif (bell, dark cloth, conductive strands, chalice or potion vessel).
- `electriccable.png`: A030, A049. Same literal object or mechanic motif (bell, dark cloth, conductive strands, chalice or potion vessel).
- `strangepotion.png`: A034, A078. Same literal object or mechanic motif (bell, dark cloth, conductive strands, chalice or potion vessel).
- `holygrail.png`: A053, A077. Same literal object or mechanic motif (bell, dark cloth, conductive strands, chalice or potion vessel).

## Approximate mappings and limits

89 entries are conservatively marked `symbolic motif substitution`; their precise reason is recorded per entry in `sources`. New designs have no supplied original art, so these are curated representations, not newly authored exact illustrations. In particular:

- A014 / A046: medical blood pack and interlaced strand stand for healing thread / suture; no literal bandage or sewing needle artwork exists in this pool.
- A017 / A048 / A079: mechanical hand or electricity stands for gloves; material and condition come from the mechanic text.
- A029 / A089: mobility broom / wind curls stand for boots and shoes; no footwear silhouette is available.
- A030 / A049: cable strands serve thread-spool / rupture-coil motifs; no isolated wound coil artwork is available.
- A013: circular brass dial serves the compass motif; A084 uses the visibly four-direction compass from passive art.
- Composite fusions emphasize one dominant readable component (blade, wave, cold, flame, current, seal or well) rather than falsely depicting the full interaction.

## Verification boundaries

Source provenance, coverage, resource paths and PNG decoding passed. Godot resource import/export and on-screen sizing are owned by integration/UI verification and are not claimed by this curation pass.
