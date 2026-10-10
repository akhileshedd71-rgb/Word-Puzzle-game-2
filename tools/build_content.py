#!/usr/bin/env python3
"""Deterministically build Folio's offline dictionary and 5,200-level campaign.

Validate without dependencies: python tools/build_content.py --validate
Rebuild dependencies: nltk==3.9.2 wordfreq==3.1.1
See docs/CONTENT.md and data/licenses for sources and licensing.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
from itertools import combinations
import json
from pathlib import Path
import random
import re
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
COUNT = 5200
WORDNET_URL = "https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/wordnet.zip"
WORDNET_SHA256 = "cbda5ea6eef7f36a97a43d4a75f85e07fccbb4f23657d27b4ccbc93e2646ab59"
SEED = 271828

# Conservative editorial exclusions; automated curation cannot replace review.
EXCLUDED = set("""
arse arses arsehole ass asses asshole bastard bitch bitches bollock bollocks
boob boobs boobies breast breasts bugger butt butts cocaine cock cocks crap
craps cunt damn damned dick dicks dildo drug drugs drunk fag fags faggot fart
farts fetish fuck fucked fucker fucking gay gays genital genitals groin hell
heroin hobo homo hooker horny incest junkie kill killed killer killing
lesbian lust lustful marijuana midget molest murder murdered murderer nazi
negro nipple nipples nude nudes nudity opium orgasm orgy penis piss pissed
porn porno prostate prostitute rape raped rapist rectum retard retarded
semen sex sexual sexy shit shitty slut sperm spunk suicide teat testicle
tit tits tobacco torture twat urine uterus vagina vulva whore weed xxx
islam jew jews jewry moslem muslim hindu hindi buddhist christian catholic
zionist satan devil demon damned pagan god gods deity jesus christ bible
allah koran quran torah mafia jihad swastika negroes chink gook kike spic
coon darkie wog dago yid dyke poof paki pikey tramp wench
aids hiv std ltd inc corp llc ceo cfo cia fbi gop gdp cpu dna rna rbc wbc
abc bbc cbs cnn dvd gps html http https lcd led lsd mph nasa nato nba nfl
nhl nyc ocd phd pta ram rom rpm tcp ufo url usa usb vip vpn wan www xml
jan feb mar apr jun jul aug sep sept oct nov dec tue wed thu fri sat sun
nil ain aint cant dont wont gonna gotta wanna thou thee thine thy shalt
oer oft ere tis twas yonder yeas yon hath doth artless
atm amp biz bot bra bum cad cos cps dal das deb doc don dug fay gal gen git
iii ira kat lam lea lit liv loo lux mac mag max may meg mei mil min mod mum
nan nee neo non obi pap pas pax pee pic pip pol pro psi rad raj rbi ref rep
rev sec sen sic sis sol sub sup tam tat tom var veg vii vox wen won xii xiv
xvi viii xiii xxii xxiii xxiv xxix xxvi xxvii xxviii xxx xxxi xxxii xxxiii xxxiv xxxv info
""".split()) - {"may", "mum", "won", "lit", "dug"}
EXCLUDED |= set("""
xxx pornographic narcotic narcotics ecstasy ganja ganjah cannabis hashish
deadly anal anus bloody shotgun handgun rifle rifles bullets bloody
""".split())
BAD_SENSE = re.compile(
    r"\b(offensive|vulgar|derogatory|slur|slurs|sexual|genital|genitals|penis|"
    r"vagina|intercourse|prostitut\w*|semen|pornograph\w*|excrement|"
    r"defecat\w*|urina\w*|masturbat\w*|obscene|racial|racist|homosexual|"
    r"slang|archaic|obsolete|abbreviation|acronym|letter of the|"
    r"drug addict|heroin|cocaine|marihuana|marijuana)\b", re.I)

# Authored definitions resolve ambiguous senses and introduce familiar words.
# Format: WORD | part of speech | meaning. RAM, SAT and SUN have ordinary senses.
AUTHORED = """
TEA|noun|A drink made by steeping dried tea leaves in hot water.
EAT|verb|To take food into your mouth and swallow it.
ATE|verb|The past tense of eat: took in and swallowed food.
CAT|noun|A small furry animal often kept as a pet.
CATS|noun|More than one cat: small furry animals often kept as pets.
ACT|verb|To do something; to take action.
SAT|verb|The past tense of sit: rested with your body supported by a seat.
CARE|noun|Attention given to keeping someone or something safe and well.
RACE|noun|A competition to see who can reach a finish line first.
ACRE|noun|A unit used to measure land, equal to 4,840 square yards.
CAR|noun|A road vehicle with four wheels, usually carrying a few people.
EAR|noun|The part of your body that hears sound.
ARE|verb|A form of be, used with you, we, they, and plural subjects.
STOP|verb|To cease moving or doing something.
POST|noun|A strong upright piece of wood or metal used as a support.
SPOT|noun|A small mark or a particular place.
TOP|noun|The highest part of something.
POT|noun|A deep round container used for cooking or growing plants.
EAST|noun|The direction in which the sun rises.
SEAT|noun|A place for someone to sit.
SEA|noun|A large area of salt water, smaller than an ocean.
RAIN|noun|Water that falls from clouds in drops.
RAN|verb|The past tense of run: moved quickly on foot.
AIR|noun|The mixture of gases around Earth that we breathe.
NOTE|noun|A short written message or reminder.
TONE|noun|The quality or character of a sound or voice.
NET|noun|A mesh of string or rope used to catch or hold things.
TEN|number|The number that comes after nine.
ONE|number|The first counting number; a single thing.
TEAM|noun|A group of people working or playing together.
MEAT|noun|The flesh of an animal used as food.
MATE|noun|A friend or companion.
LAMP|noun|A device that produces light.
PAL|noun|A friend.
LAP|noun|The flat area between your waist and knees when sitting.
SAND|noun|Tiny loose grains of rock found on beaches and in deserts.
AND|conjunction|A word used to join words, phrases, or ideas.
SAD|adjective|Feeling unhappy or sorrowful.
STAR|noun|A huge distant ball of glowing gas seen as a point of light at night.
ART|noun|Creative work made to express ideas or feelings.
RAT|noun|A rodent with a long thin tail, usually larger than a mouse.
TAR|noun|A thick dark sticky substance used on roads and roofs.
RIDE|verb|To travel on or in a vehicle or animal.
RED|adjective|The color of a ripe tomato.
DIE|noun|A small cube marked with numbers, used in games.
WARM|adjective|Having a comfortably high temperature, without being hot.
ARM|noun|The part of the body between the shoulder and the hand.
RAM|noun|An adult male sheep.
WAR|noun|Armed fighting between countries or groups.
COAT|noun|An outer piece of clothing worn to keep warm or dry.
COT|noun|A small simple bed.
OAT|noun|A cereal plant whose grain is used for food.
FARM|noun|An area of land used to grow crops or raise animals.
FAR|adverb|At or to a great distance.
BOAT|noun|A small vessel for traveling on water.
BAT|noun|A flying mammal that is usually active at night.
TAB|noun|A small flap or label used to pull, identify, or select something.
TALE|noun|A story, especially one about imagined events.
LATE|adjective|Arriving or happening after the expected time.
SEAL|noun|A sea mammal with flippers that also rests on land or ice.
SALE|noun|An event in which goods are sold at reduced prices.
TAPE|noun|A long narrow strip, often sticky, used to fasten things.
PEAT|noun|Partly decayed plant material found in wet ground.
APE|noun|A primate without a tail, such as a gorilla or chimpanzee.
PET|noun|An animal kept at home for companionship.
PALE|adjective|Light in color or having less color than usual.
LEAP|verb|To jump a long way or to a great height.
PLEA|noun|An urgent or heartfelt request.
SUN|noun|The star at the center of our solar system.
WORD|noun|A unit of language with a meaning, spoken or written.
FOLIO|noun|A sheet of paper folded once to make two leaves of a book.
READ|verb|To understand the meaning of written or printed words.
INK|noun|A colored liquid or paste used for writing or printing.
PAGE|noun|One side of a sheet of paper in a book or document.
BOOK|noun|A collection of written or printed pages bound together.
OWL|noun|A bird of prey with large eyes, usually active at night.
PEN|noun|An instrument for writing or drawing with ink.
HUE|noun|A color or shade of a color.
ROW|noun|A line of people or things arranged side by side.
SOW|verb|To plant seeds by placing or scattering them in soil.
TAN|noun|A light brown color.
SUE|verb|To bring a legal claim against someone in court.
AWE|noun|A feeling of wonder and deep respect.
GEM|noun|A valuable stone cut and polished for decoration.
ARC|noun|A curved line that forms part of a circle.
NOD|verb|To move your head down and up to show agreement.
BOW|noun|A knot with two loops, made by tying ribbon or string.
FAN|noun|A device with moving blades that circulates air.
ACE|noun|A playing card marked with a single symbol.
ODD|adjective|Unusual or unexpected.
EVEN|adjective|Flat, level, or equal.
ANIME|noun|A style of animation originating in Japan.
MEME|noun|An idea, image, or joke that is copied and spread between people.
APP|noun|A software application that performs a task on a computer or mobile device.
DATA|noun|Facts or information collected for reference or analysis.
MAY|verb|Used to express permission or that something is possible.
MUM|noun|An informal word for mother, especially in British English.
WON|verb|The past tense of win: achieved victory in a contest.
LIT|verb|The past tense of light: made something bright or started it burning.
DUG|verb|The past tense of dig: made a hole by removing soil.
DESPITE|preposition|Without being prevented by; in spite of.
WAS|verb|A past-tense form of be, used with I, he, she, and it.
WERE|verb|A past-tense form of be, used with you, we, and they.
HAS|verb|A form of have: owns, holds, or possesses something.
HAD|verb|The past tense of have: owned, held, or possessed something.
THE|article|Used before a noun to refer to a particular person or thing.
HER|pronoun|Used for a female person as an object, or to show what belongs to her.
HIS|pronoun|Belonging to a male person previously mentioned.
SHE|pronoun|Used to refer to a female person previously mentioned.
HIM|pronoun|Used for a male person as the object of a verb or preposition.
YOU|pronoun|The person or people being spoken or written to.
OUR|determiner|Belonging to or connected with us.
THEIR|determiner|Belonging to or connected with them.
THEY|pronoun|People or things previously mentioned; also a person of unspecified gender.
THIS|determiner|The particular person or thing nearby or being discussed.
THAT|determiner|A particular person or thing being indicated or discussed.
THESE|determiner|The plural of this: particular people or things nearby.
THOSE|determiner|The plural of that: particular people or things indicated.
WITH|preposition|Accompanied by, together with, or using something.
FROM|preposition|Used to show the starting place, time, or source of something.
INTO|preposition|Toward the inside of a place or thing.
ONTO|preposition|To a position on the surface of something.
THAN|conjunction|Used when comparing two people, things, or amounts.
WHEN|adverb|At what time, or at the time that something happens.
WHAT|pronoun|Used to ask for information about a thing or event.
WHO|pronoun|Used to ask which person, or to refer to a person just mentioned.
WHOM|pronoun|The object form of who: which person receives an action.
WHICH|determiner|Used to ask or specify one or more from a known set.
DEER|noun|A hoofed woodland animal; males of most species grow antlers.
FIFTH|adjective|Coming after the fourth and before the sixth in a series.
MEN|noun|More than one man: adult male people.
OFF|adverb|Away from a place, position, or attachment.
COD|noun|A large sea fish often used as food.
FIN|noun|A flat part on a fish's body used to swim, balance, or steer.
FIG|noun|A soft sweet fruit containing many tiny seeds.
VAN|noun|A road vehicle with space for carrying goods or several passengers.
CUB|noun|A young bear, lion, or other similar animal.
BOB|verb|To move quickly up and down.
BID|noun|An offer of a price, especially at an auction.
LET|verb|To allow someone to do something.
GET|verb|To receive, obtain, or come to have something.
SEE|verb|To notice or observe something with your eyes.
RUN|verb|To move quickly on foot, with brief moments when both feet leave the ground.
PUT|verb|To move or place something in a particular position.
CUT|verb|To divide or make an opening in something using a sharp edge.
SAW|verb|The past tense of see: noticed something with your eyes.
BUY|verb|To get something by paying money for it.
DRY|adjective|Free from water or moisture.
WET|adjective|Covered with or containing water or another liquid.
SHY|adjective|Nervous or uncomfortable around other people.
FEW|determiner|A small number of people or things.
BAD|adjective|Not good; harmful, unpleasant, or of poor quality.
HIT|verb|To strike or come into forceful contact with something.
LOW|adjective|Not far above the ground or below the usual level.
RAW|adjective|Not cooked, or still in a natural, unprocessed state.
RIP|verb|To tear something apart or make a tear in it.
RUB|verb|To move something back and forth against a surface.
FRY|verb|To cook food in hot oil or fat.
FIT|verb|To be the right shape or size for something.
FIX|verb|To repair something or make it work correctly.
BEE|noun|A flying insect that collects nectar and pollen from flowers.
ANT|noun|A small insect that lives in a colony and has six legs.
DOG|noun|A domesticated animal often kept as a pet or working companion.
EGG|noun|An oval object laid by a bird or other animal, in which a young animal can develop.
TOY|noun|An object made for playing with.
TRY|verb|To make an effort to do or achieve something.
WHY|adverb|For what reason or purpose.
SAY|verb|To speak words or express something in words.
ALL|determiner|The whole amount or every member of a group.
ANY|determiner|One or some, without specifying which.
AID|noun|Help or support given to someone who needs it.
AGE|noun|The length of time someone or something has existed.
MAD|adjective|Very angry.
MUG|noun|A large cup with a handle, used for hot drinks.
NIP|verb|To pinch or bite lightly and quickly.
SUM|noun|The total found by adding numbers or amounts.
USE|verb|To do something with an object, skill, or resource for a purpose.
ZIP|verb|To fasten with a zipper, or to move very quickly.
JOG|verb|To run at a steady, gentle pace.
HUM|verb|To make a low continuous sound with your lips closed.
PIN|noun|A small thin piece of metal with a sharp point, used to fasten things.
HOG|noun|A pig, especially one raised for food.
COW|noun|An adult female animal of the cattle family, often kept for milk.
SIC|adverb|A word in quoted text indicating that an unusual spelling or error is in the original.
"""
OVERRIDES = {}
for _line in AUTHORED.strip().splitlines():
    _word, _pos, _meaning = _line.split("|", 2)
    OVERRIDES[_word] = (_meaning, _pos)

STARTERS = [
    ("TEA", "TEA EAT ATE"), ("CATS", "CAT ACT SAT"),
    ("CARE", "CARE RACE CAR EAR ARE"), ("STOP", "STOP POST SPOT TOP POT"),
    ("EAST", "EAST SEAT EAT TEA SEA"), ("RAIN", "RAIN RAN AIR"),
    ("NOTE", "NOTE TONE NET TEN ONE"), ("TEAM", "TEAM MEAT MATE EAT TEA"),
    ("LAMP", "LAMP PAL LAP"), ("SAND", "SAND AND SAD"),
    ("STAR", "STAR ART RAT TAR"), ("RIDE", "RIDE RED DIE"),
    ("WARM", "WARM ARM RAM"), ("COAT", "COAT CAT ACT COT OAT"),
    ("FARM", "FARM ARM FAR RAM"), ("BOAT", "BOAT BAT TAB OAT"),
    ("TALE", "TALE LATE TEA EAT"), ("SEAL", "SEAL SALE SEA"),
    ("TAPE", "TAPE APE PET"), ("PALE", "PALE LEAP PLEA LAP"),
]

def signature(word):
    return "".join(sorted(word))

def load_wordnet(cache):
    import nltk
    archive = cache / "corpora" / "wordnet.zip"
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        print("Downloading WordNet 3.0 with TLS verification...")
        with urllib.request.urlopen(WORDNET_URL, timeout=120) as response:
            content = response.read()
        if hashlib.sha256(content).hexdigest() != WORDNET_SHA256:
            raise RuntimeError("WordNet archive checksum mismatch; refusing data")
        archive.write_bytes(content)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != WORDNET_SHA256:
        raise RuntimeError("Cached WordNet archive checksum mismatch")
    nltk.data.path.insert(0, str(cache))
    from nltk.corpus import wordnet
    return wordnet, archive

def build_lexicon(wn):
    from wordfreq import zipf_frequency
    lexicon, frequencies = {}, {}
    pos_names = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective", "r": "adverb"}
    for word in sorted(wn.all_lemma_names()):
        if not re.fullmatch(r"[a-z]{3,8}", word) or word in EXCLUDED:
            continue
        frequency = zipf_frequency(word, "en", wordlist="large")
        if frequency < (4.0 if len(word) == 3 else 3.4 if len(word) == 4 else 3.2):
            continue
        # Exact lowercase lemmas exclude uppercase acronyms and proper names.
        senses = [s for s in wn.synsets(word)
                  if any(l.name() == word for l in s.lemmas())
                  and not s.instance_hypernyms() and not BAD_SENSE.search(s.definition())]
        if not senses:
            continue
        # Prefer corpus-attested common senses over a rare noun-first meaning.
        senses.sort(key=lambda s: -sum(l.count() for l in s.lemmas() if l.name() == word))
        sense = senses[0]
        if len(word) == 3 and not any(l.count() > 0 for l in sense.lemmas() if l.name() == word):
            continue
        meaning = sense.definition().strip()
        if len(meaning) > 210:
            shorter = [s for s in senses if len(s.definition()) <= 210]
            if not shorter:
                continue
            sense = shorter[0]
            meaning = sense.definition().strip()
        meaning = meaning.replace("`", "'")
        # NLTK can leave dangling attribution when removing quoted examples.
        meaning = re.sub(r";\s*(?:;\s*)*[-–].*$", "", meaning).strip()
        meaning = re.sub(r"(?:;\s*){2,}", "; ", meaning).rstrip(" ;")
        meaning = meaning[0].upper() + meaning[1:]
        if meaning[-1] not in ".!?":
            meaning += "."
        lexicon[word.upper()] = {"meaning": meaning, "pos": pos_names[sense.pos()]}
        frequencies[word.upper()] = frequency
    for word, (meaning, pos) in OVERRIDES.items():
        lexicon[word] = {"meaning": meaning, "pos": pos}
        frequencies[word] = zipf_frequency(word.lower(), "en", wordlist="large")
    return dict(sorted(lexicon.items())), frequencies

def add_bonus_inflections(lexicon, wn):
    """Accept common plurals and verb forms without padding the level pool."""
    from wordfreq import top_n_list, zipf_frequency
    additions = {}
    for word in top_n_list("en", 100000):
        upper = word.upper()
        if not re.fullmatch(r"[a-z]{3,8}", word) or word in EXCLUDED or upper in lexicon:
            continue
        if zipf_frequency(word, "en", wordlist="large") < 3.8:
            continue
        noun_base = wn.morphy(word, wn.NOUN) if word.endswith("s") else None
        verb_base = wn.morphy(word, wn.VERB) if word.endswith(("s", "ed", "ing")) else None
        for base, pos in [(noun_base, "noun"), (verb_base, "verb")]:
            if not base or base == word or base.upper() not in lexicon:
                continue
            entry = lexicon[base.upper()]
            if entry["pos"] != pos:
                senses = [s for s in wn.synsets(base, pos=wn.NOUN if pos == "noun" else wn.VERB)
                          if any(l.name() == base for l in s.lemmas())
                          and not s.instance_hypernyms() and not BAD_SENSE.search(s.definition())
                          and len(s.definition()) <= 210]
                if not senses:
                    continue
                sense = max(senses, key=lambda s: sum(l.count() for l in s.lemmas() if l.name() == base))
                meaning = re.sub(r";\s*(?:;\s*)*[-–].*$", "", sense.definition().replace("`", "'")).strip()
                meaning = re.sub(r"(?:;\s*){2,}", "; ", meaning).rstrip(" ;.")
                entry = {"meaning": meaning[0].upper() + meaning[1:] + "."}
            prefix = "Plural" if pos == "noun" else "A grammatical form"
            additions[upper] = {"meaning": f"{prefix} of {base}: {entry['meaning']}", "pos": pos}
            break
    lexicon.update(additions)
    return dict(sorted(lexicon.items()))

def all_formable(rack, index):
    words = set()
    for size in range(3, len(rack) + 1):
        for letters in set(combinations(rack, size)):
            words.update(index.get("".join(letters), []))
    return sorted(words)

def build_levels(lexicon, frequencies):
    index = defaultdict(list)
    for word in lexicon:
        index[signature(word)].append(word)
    starters = {signature(rack) for rack, _ in STARTERS}
    candidates = []
    for rack in sorted(index):
        if rack in starters:
            continue
        words = all_formable(rack, index)
        if len(words) < 3:
            continue
        anchor = min(index[rack], key=lambda w: (-frequencies[w], w))
        complexity = (len(rack) * 0.95 + max(0.0, 5.2 - frequencies[anchor]) * 1.45
                      + sum(letter in "JQXZ" for letter in rack) * 0.28
                      + (len(rack) - len(set(rack))) * 0.09)
        candidates.append((complexity, rack, anchor, words))
    candidates.sort(key=lambda x: (x[0], x[1]))
    if len(candidates) < COUNT - len(STARTERS):
        raise RuntimeError(f"Only {len(candidates)} candidate racks; need {COUNT}")
    rng = random.Random(SEED)
    levels = []
    for rack, words in STARTERS:
        levels.append({"id": len(levels) + 1, "letters": rack, "words": words.split(), "difficulty": 1})
    selected = candidates[:COUNT - len(levels)]
    for start in range(0, len(selected), 20):
        band = selected[start:start + 20]
        rng.shuffle(band)
        selected[start:start + 20] = band
    for _complexity, rack, anchor, words in selected:
        level_id = len(levels) + 1
        base_difficulty = 1 if level_id <= 100 else 2 if level_id <= 650 else 3 if level_id <= 1800 else 4 if level_id <= 3500 else 5
        relief = level_id % 10 == 0
        challenge = level_id % 25 == 0 and not relief
        difficulty = max(1, base_difficulty - 1) if relief else min(5, base_difficulty + int(challenge))
        target_count = min(len(words), 3 if relief else difficulty + 2)
        ranked = sorted(words, key=lambda w: (len(w) * 0.12 - frequencies[w], w))
        targets = [] if relief else [anchor]
        if challenge:
            learning = min(words, key=lambda w: (frequencies[w] - len(w) * 0.1, w))
            if learning not in targets:
                targets.append(learning)
        for word in ranked:
            if len(targets) >= target_count:
                break
            if word not in targets:
                targets.append(word)
        targets.sort(key=lambda w: (len(w), w))
        letters = list(rack)
        rng.shuffle(letters)
        levels.append({"id": level_id, "letters": "".join(letters), "words": targets, "difficulty": difficulty})
    return levels

def validate(lexicon, levels):
    errors = []
    if not isinstance(lexicon, dict) or not isinstance(levels, list):
        raise ValueError("Expected lexicon object and levels array")
    if len(levels) != COUNT:
        errors.append(f"Expected {COUNT} levels, got {len(levels)}")
    seen_racks, used_words = set(), set()
    for word, entry in lexicon.items():
        if not re.fullmatch(r"[A-Z]{3,8}", word):
            errors.append(f"Invalid lexicon key {word!r}")
        if not isinstance(entry, dict) or not entry.get("meaning", "").strip() or not entry.get("pos", "").strip():
            errors.append(f"Missing definition or part of speech: {word}")
        if word.lower() in EXCLUDED and word not in OVERRIDES:
            errors.append(f"Excluded word leaked into lexicon: {word}")
    for expected_id, level in enumerate(levels, 1):
        label = f"Level {expected_id}"
        if set(level) != {"id", "letters", "words", "difficulty"}:
            errors.append(f"{label}: incorrect fields")
        if level.get("id") != expected_id:
            errors.append(f"{label}: IDs must be consecutive")
        letters = level.get("letters", "")
        if not re.fullmatch(r"[A-Z]{3,8}", letters):
            errors.append(f"{label}: rack must have 3–8 uppercase letters")
        rack = signature(letters)
        if rack in seen_racks:
            errors.append(f"{label}: duplicate letter multiset {rack}")
        seen_racks.add(rack)
        words = level.get("words", [])
        if not 3 <= len(words) <= 7 or len(set(words)) != len(words):
            errors.append(f"{label}: expected 3–7 unique targets")
        if not 1 <= level.get("difficulty", 0) <= 5:
            errors.append(f"{label}: difficulty outside 1–5")
        for word in words:
            if word not in lexicon:
                errors.append(f"{label}: {word} has no dictionary definition")
            if Counter(word) - Counter(letters):
                errors.append(f"{label}: cannot form {word} from {letters}")
            used_words.add(word)
        if expected_id <= 20 and (len(letters) > 4 or any(len(w) > 4 for w in words)):
            errors.append(f"{label}: onboarding words must be short")
    if errors:
        raise ValueError("\n".join(errors[:100]))
    print(f"PASS: {len(levels):,} levels; {len(seen_racks):,} distinct letter multisets; {len(used_words):,} target words; {len(lexicon):,} defined words.")
    print("Rack sizes:", dict(sorted(Counter(len(level["letters"]) for level in levels).items())))
    print("Difficulty:", dict(sorted(Counter(level["difficulty"] for level in levels).items())))
    return {"levels": len(levels), "racks": len(seen_racks), "targets": len(used_words), "lexicon": len(lexicon)}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate", action="store_true", help="Validate bundled JSON offline using only Python's standard library")
    parser.add_argument("--cache", type=Path, default=Path("/tmp/folio-nltk"), help="Download cache outside the checkout")
    args = parser.parse_args()
    if args.validate:
        validate(json.loads((ROOT / "data/lexicon.json").read_text()), json.loads((ROOT / "data/levels.json").read_text()))
        return
    try:
        import nltk
        import wordfreq
        from importlib.metadata import version
        if version("nltk") != "3.9.2" or version("wordfreq") != "3.1.1":
            raise RuntimeError("Rebuild requires nltk==3.9.2 and wordfreq==3.1.1")
    except ImportError as error:
        raise SystemExit("Install generator dependencies: pip install nltk==3.9.2 wordfreq==3.1.1") from error
    wn, archive = load_wordnet(args.cache)
    lexicon, frequencies = build_lexicon(wn)
    levels = build_levels(lexicon, frequencies)
    lexicon = add_bonus_inflections(lexicon, wn)
    validate(lexicon, levels)
    (ROOT / "data").mkdir(exist_ok=True)
    for filename, payload in [("lexicon.json", lexicon), ("levels.json", levels)]:
        (ROOT / "data" / filename).write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    license_dir = ROOT / "data/licenses"
    license_dir.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        (license_dir / "WORDNET-LICENSE.txt").write_bytes(bundle.read("wordnet/LICENSE"))
    print("Wrote data/lexicon.json, data/levels.json, and the WordNet license.")

if __name__ == "__main__":
    main()
