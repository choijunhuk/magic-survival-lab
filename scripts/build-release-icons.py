#!/usr/bin/env python3
"""Package curator-selected upstream PNGs unchanged; never synthesize replacement art."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Selection follows inspection of the original magic, artifact, and passive contact
# sheets. These are motif matches for new designs, not claims of original identity.
# A '~' marks an intentionally approximate / symbolic visual substitution.
SELECTIONS = r'''
M09|magic/flameStorm|Descending red flame strokes express falling embers and ignition.
M10|magic/blaster|Parallel pale needle strokes express a piercing frost-needle fan.~
M11|magic/magneticField|Orbiting white electric nodes express the persistent storm ring.
M12|magic/blackHole|A dark circular well with a luminous rim expresses gravitational attraction.
M13|artifact/assassination|Three sharp red blade strokes express an executing shadow dagger.
M14|artifact/mandrake|A green rooted sprout expresses a life seed and recovery.
M15|artifact/magicseal|A clear cyan triangular glyph expresses a slowing seal.
M16|artifact/manaore|A spiked violet crystal expresses a crystal contact mine.~
M17|magic/breathOfFire|Forward branching red flame strokes express a directed heat wave.
M18|magic/winterStorm|A horizontal icy band expresses a traversable glacial strip.
M19|artifact/lightningrod|A charged rod provides a precise mark for delayed lightning.~
M20|magic/reaction|Cyan bending arcs around a white impact express projectile deflection.~
M21|artifact/shadowcape|A flowing grey-black cloak expresses a shadow shroud.
M22|passive/bloodmagic|The red circular blood glyph expresses a blood-powered recovery pulse.~
M23|artifact/deathbell|An actual hanging bell expresses interruption and silence.
M24|artifact/magicscroll|An inscribed hanging charm expresses a protective return talisman.~
F05|magic/brandish|Intersecting thin cyan slashes express branching glasslike projectiles.~
F06|magic/terraCurrent|Cyan current arcs express electrical charging along an orbit.
F07|magic/hyperion|Contrasting blue and orange energy lobes express the fire/cold boundary.
F08|magic/orbitalStrike|Descending strikes into a blue ground ring express a gravitational meteor fall.
F09|magic/telekineticSword|Multiple spectral blade strokes express a blade with a secondary dagger.
F10|magic/astrape|Forked pale lightning strokes express frost-enhanced branching thunder.
F11|magic/warClimate|Falling red strokes over a burning ground line express embers after a strike.
F12|passive/arcaneeffuse|An expanding radial green glyph expresses a wave leaving seal circles.~
F13|magic/lightningBreath|Red branching electrical strokes express a heat-linked lightning circuit.
F14|magic/manaSpear|A narrow icy-blue energy spear expresses a chilled piercing lance.
F15|magic/energyBombardment|A burst of luminous particles expresses remotely detonated crystal mines.~
F16|magic/vortex|Purple circular eddies express a vulnerable-target abyssal rotation.
F17|artifact/phoenixbow|A burning curved weapon expresses shadow-weapon ignition spread.~
F18|magic/lightningCalibration|A ring of blue lightning expresses a calibrated timed strike.~
F19|magic/blackDeath|Dark violet mist expresses a polar-night shroud; its cold component is symbolic.~
F20|passive/chakra|A flowerlike radial glyph expresses a life-seed collection pulse.~
F21|artifact/gravityorb|Concentric green gravitational rings express a well that gathers life progress.~
F22|magic/empyreanWrath|Pale branching lightning expresses the strike following a bell delay.~
F23|magic/ghastlyRampage|Outward pale spectral blades express blades thrown on return.~
F24|magic/greatImpact|Multiple descending red fragments express a mine-shattering comet.
F25|magic/hellfire|A broad curved flame stroke expresses heat spreading in an arc.
F26|artifact/etherarrow|A fan of slender cyan weapon strokes expresses a cold piercing dagger.~
F27|magic/rulerOfStorms|Concentric curved wave marks express a deflection-triggered force pulse.
F28|passive/concentration|Concentric green rings express a restorative seed/seal field.~
F29|magic/genesis|A dark violet descending particle mass expresses a night comet.~
F30|magic/superCyclone|A compact white spiral expresses a compressed storm well.
F31|artifact/forcefield|A pale cyan geometric barrier expresses the refracting ice wall.~
F32|magic/demonEquation|Red dropletlike particulate strokes express blood turning into ember rain.~
F33|artifact/enchant|A red-crossed downward blade expresses a marked execution dagger.~
F34|passive/seal|Purple repeated glyph strokes express overlapping seals and slowing fields.~
F35|magic/phoenix|A bright flame silhouette expresses the burst at the return position.~
F36|magic/currentOverload|Repeated white lightning traces express current returning to a shooter.
A013|artifact/goldenroulette|A round gold dial expresses a copper navigation instrument; roulette is an acknowledged compass substitute.~
A014|artifact/bloodpack|A medical blood pack makes the healing role readable; no thread icon exists.~
A015|artifact/hppotion|A visible red healing bottle expresses the emergency recovery supply.~
A016|artifact/ouroboros|A dark ornamental circular ring expresses the obsidian ring form.~
A017|artifact/machinearm|A metallic hand silhouette expresses a projectile-enhancing silver glove.~
A018|artifact/pyramid|A heavy stone weight silhouette expresses the gravity duration weight.~
A019|artifact/cauldron|A glowing red furnace vessel expresses sustained ignition.~
A020|artifact/snowflakecrown|Pale pointed ice crystals express the frost pin and larger cold area.~
A021|artifact/deathbell|A hanging bell directly represents the bell fragment motif.
A022|artifact/secondheart|A glowing organic heart expresses a pulse stone that strengthens recovery.~
A023|artifact/manashield|A blue shield boundary directly represents reduced incoming damage.
A024|artifact/spiderweb|Interlaced strands express a knot controlling repeated area ticks.~
A025|artifact/glassorb|Cool blue glass drops express stored rain and moving cold damage; bottle form is approximate.~
A026|artifact/clairvoyance|An eye in a cyan lens expresses increased target detection.~
A027|artifact/gunpowder|A granular powder scatter expresses increased explosive area.
A028|artifact/longinusspear|A narrow pointed gold-red shaft expresses a first-strike brass needle.~
A029|artifact/broom|A mobility tool expresses the brief movement boost; no boot art is supplied.~
A030|artifact/electriccable|Coiled grey-blue cable strands express a grey thread spool and mark duration.~
A031|artifact/spellbag|An actual tan pouch directly represents the collection bag.
A032|artifact/pocketwatch|A clock face directly represents a wrist-watch warning timer.~
A033|artifact/geometry|A vivid straight-edged glyph expresses chalk extending a seal area.~
A034|artifact/strangepotion|An actual narrow glass bottle expresses the extra-seed vessel.
A035|artifact/golemcore|A dark rocky mass with a glowing core expresses a meteor stone fragment.~
A036|artifact/crow|A feathered bird silhouette expresses a guide feather and advance warning.~
A037|artifact/sample|A jar containing particulate material expresses a bag of ignition ash.~
A038|artifact/sapphire|A clear blue crystal expresses stronger consumed electrical charge.~
A039|artifact/shadowcape|Grey-black draped cloth directly conveys fabric extending vulnerability.~
A040|artifact/weathercontroller|Circular air-current markings express a wind vane's movement response.~
A041|artifact/lantern|An actual turquoise lantern expresses improved visibility in the shroud.
A042|artifact/ancienttreestaff|A wooden shaft expresses the planted stake extending mine life.~
A043|artifact/circularsawblade|Metal teeth directly express the enlarged contact area of orbiting blades.~
A044|artifact/manacircuit|Branching conductive tracks express an electrical knot extending a chain jump.~
A045|artifact/mooncrystal|A crescent of icy blue crystal expresses a longer cold strip; cord form is approximate.~
A046|artifact/dna|A thin interlaced strand expresses suturing and recovery; no sewing needle image is supplied.~
A047|artifact/maskedball|A visible ornamental mask expresses the mask-cord targeting motif.~
A048|artifact/cyborg|A mechanical gloved hand expresses the old glove increasing pulse reach.~
A049|artifact/electriccable|Looped blue conductive cables express a rupture coil and electrical extra hit.~
A050|artifact/sulfur|Sharp yellow mineral shards express volcanic material and ignition explosions.~
A051|artifact/mirror|An actual blue mirror directly expresses a frost mirror.
A052|artifact/singularity|Lines converging to a central point express focused gravity collapse.~
A053|artifact/holygrail|A shaded golden cup expresses a shadow chalice storing a next-hit benefit.~
A054|artifact/halo|A luminous circular ring directly expresses a life ring and recovery pulse.
A055|artifact/magicgrimoire|An inscribed closed tablet/book expresses the sealed slab cooldown effect.~
A056|artifact/magicbullet|A pointed luminous projectile expresses a penetrating arcane awl.~
A057|artifact/radar|A concentric attraction/detection diagram expresses reclaiming loose experience; no horseshoe magnet exists.~
A058|artifact/dragonscale|Overlapping protective scales express sentinel armour near an elite.~
A059|artifact/jetengine|A radial propulsion device expresses an evasive launch platform.~
A060|artifact/pandorabox|A contained concentric vortex expresses a vacuum vessel retaining slow; jar silhouette is approximate.~
A061|artifact/hourglass|An actual hourglass directly expresses conditional cooldown reduction.
A062|artifact/ironmaiden|A metal protective enclosure expresses temporary silver-thread armour.~
A063|artifact/treasuremap|A map with a path marker expresses the return destination and movement cue.~
A064|artifact/crucifix|A protective cross expresses a healing-triggered defensive emblem.~
A065|artifact/coreenergy|A brilliant orb encircled by energy loops expresses stored overload charge.
A066|artifact/worldtreeleaf|A branching green leaf directly expresses a life seed's enduring recovery.
A067|artifact/mjolnir|An actual hammer directly expresses a delayed impact aftershock.
A068|passive/energyengineering|Two orbital loops around a core express an additional orbiting blade.~
A069|artifact/otherworldlytentacle|Tangled dark-violet tendrils express a shadow knot extending dagger reach.~
A070|artifact/aurora|A blue-green hanging crescent expresses a cold necklace and lingering frost.~
A071|artifact/mutagen|A branched skeletal green form expresses conductive bone; literal bone anatomy is approximate.~
A072|artifact/akashicrecord|An inscribed record fragment expresses a remembered choice and reroll.~
A073|artifact/warflag|A standing banner directly conveys an event route marker.~
A074|artifact/target|A concentric target face expresses precision on the first high-health target.~
A075|artifact/keyring|Linked metal rings directly express fusion-component binding.~
A076|artifact/dragontongue|Flexible red lash shapes express a vulnerability-extending whip.~
A077|artifact/holygrail|A luminous golden cup directly expresses the amplification chalice; its fire condition remains in the text.~
A078|artifact/strangepotion|A dark violet glass bottle directly expresses the shadow recovery potion.~
A079|artifact/lightning|A sharp white electrical stroke expresses grounding and stored storm damage; glove form is approximate.~
A080|artifact/spacetimecircuit|A cool circular mechanism expresses a cooling ring shortening cast intervals.~
A081|magic/ageOfTheSun|Two torn orange solar masses express a split solar explosion.
A082|magic/frozenHeart|A pale icy radial burst expresses absolute-zero cold control.~
A083|artifact/crown|A pointed gold crown directly conveys the lightning crown; its electrical effect is conveyed by the text.
A084|passive/pioneer|A blue four-direction compass expresses the abyss compass; the gravitational absorption remains in its mechanic text.~
A085|artifact/tarotcard|Occult cards express a shadow contract under low health.~
A086|artifact/rose|A blooming flower directly expresses life flowering after seed collection.
A087|artifact/dimensionalgate|An actual luminous portal expresses a seal gate cancelling a charge.~
A088|artifact/crystalprism|A clear faceted crystal directly represents the origin crystal and arcane mark.~
A089|artifact/breeze|Directional white wind curls express movement along the horizon; no shoe icon exists.~
A090|artifact/dragonheart|A burning heart directly expresses a meteor heart releasing fragments.~
A091|artifact/clockwork|A mechanical winding gear assembly directly expresses one-use restart clockwork.
A092|magic/prismSpray|Multicoloured refracted rays express a prism combining three schools.
A093|artifact/magicsword|A starry curved sword directly expresses the blade constellation.
A094|artifact/deathbell|A hanging bell directly expresses the stopped-bell motif; the delay appears in its mechanic text.
A095|artifact/eclipse|A dark red-black circular core expresses the heart of night and enlarged shroud.~
A096|artifact/fourleafclover|A single green leaf symbol expresses the last-leaf protection; a clover is an explicit leaf substitute.~
'''


def main():
    catalog = json.loads((ROOT / 'assets/catalog.json').read_text())
    names = json.loads((ROOT / 'assets/display-names.json').read_text())['names']
    content = json.loads((ROOT / 'godot/data/release_content.json').read_text())
    entries = {e['canonicalId']: e for category in ['upgrades', 'fusions', 'artifacts']
               for e in content[category] if 'canonicalId' in e}
    expected = {f'M{i:02}' for i in range(9, 25)} | {f'F{i:02}' for i in range(5, 37)} | {f'A{i:03}' for i in range(13, 97)}
    files = {entry['file']: entry for entry in catalog['files']}
    categories = {'magic': 'magicImages', 'artifact': 'artifactImages', 'passive': 'passiveImages'}
    out = ROOT / 'godot/assets/release-icons'
    out.mkdir(parents=True, exist_ok=True)
    icons, sources, selected = {}, [], set()
    for row in SELECTIONS.strip().splitlines():
        canonical, image, reason = row.split('|', 2)
        if canonical in selected:
            raise ValueError(f'Duplicate canonical ID: {canonical}')
        selected.add(canonical)
        category, stem = image.split('/')
        original = f'assets/{categories[category]}/{stem}.png'
        provenance = files[original]
        src = ROOT / original
        digest = hashlib.sha256(src.read_bytes()).hexdigest()
        if digest != provenance['sha256']:
            raise ValueError(f'Original source hash mismatch: {original}')
        target = out / src.name
        # Prefix only if a same-name source in another category would collide.
        if any(s['assetPath'].endswith('/' + src.name) and s['originalFile'] != original for s in sources):
            target = out / f'{category}-{src.name}'
        shutil.copyfile(src, target)
        if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError(f'Copy hash mismatch: {target}')
        runtime = entries[canonical]['id']
        relative = str(target.relative_to(ROOT / 'godot'))
        icons[runtime] = relative
        approximate = reason.endswith('~')
        sources.append({'runtimeId': runtime, 'canonicalId': canonical, 'designName': entries[canonical]['name'],
                        'assetPath': relative, 'originalFile': original, 'originalUrl': provenance['source'],
                        'sourceDisplayName': names.get(original, src.stem), 'sha256': digest,
                        'gitBlobSha': provenance['gitBlobSha'], 'reason': reason.rstrip('~'),
                        'match': 'symbolic motif substitution' if approximate else 'direct visual motif',
                        'identityNote': 'Reused upstream artwork; the source name is not the identity of this new design.'})
    if selected != expected or len(icons) != 132:
        raise ValueError(f'Coverage mismatch: missing={expected-selected}, extra={selected-expected}')
    manifest = {'icons': icons, 'sources': sources, 'sourceRepository': catalog['repository'],
                'sourceCommit': catalog['commit'], 'curationMethod': 'Visual contact-sheet inspection, design/mechanic motif matching, unchanged byte copies.'}
    (ROOT / 'godot/data/release_icons.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(f'Packaged {len(icons)} choices from {len(set(icons.values()))} unique unchanged PNGs.')
    print(f'Symbolic substitutions: {sum(s["match"] == "symbolic motif substitution" for s in sources)}.')


if __name__ == '__main__':
    main()
