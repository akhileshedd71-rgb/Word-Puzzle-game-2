# Folio English content

The bundled campaign contains **5,200 playable puzzles with 5,200 different
letter multisets**, 5,810 distinct target words, and an offline dictionary of
10,011 words with meanings and parts of speech. A different ordering of the
same letters never counts as another campaign puzzle.

All game content is bundled in JSON. Playing, checking words, showing
definitions, daily selection, and reviewing saved vocabulary need no dictionary
API, login, key, or network connection.

## Files and schema

- `data/levels.json`: an array of objects containing `id` (1 through 5200),
  `letters` (3–8 uppercase letters), `words` (3–7 distinct uppercase targets),
  and `difficulty` (1–5).
- `data/lexicon.json`: an object keyed by uppercase words. Each value contains
  `meaning` and `pos` strings. Every target has a definition. Other formable
  words in this dictionary can be accepted as bonus discoveries.
- `tools/build_content.py`: deterministic generation and dependency-free
  validation.
- `data/licenses/`: upstream licenses, attribution, and content licensing.

Repeated letters are physical tiles: `LETTER` needs two E tiles and two T
tiles. Target validation uses character counts rather than membership alone.
Targets never exceed the rack's supply of a letter.

## Editorial and difficulty approach

The first 20 puzzles are hand-selected, with three- and four-letter words and
authored definitions. The first puzzle uses **TEA / EAT / ATE** to introduce
anagrams. Familiar groups follow, such as **CARE / RACE / CAR / EAR / ARE**.

The remainder is generated from dictionary anchors. Racks are scored by
length, anchor frequency, rare letters, and repeated letters. Nearby puzzles
are shuffled in small bands with a fixed seed. Normal puzzles include an
anchor using the whole rack, plus familiar shorter discoveries.

| Campaign range | Main difficulty | Normal target count |
| --- | --- | --- |
| 1–100 | 1 · introductory | 3 (starter puzzles vary) |
| 101–650 | 2 · familiar | 4 |
| 651–1800 | 3 · developing | 5 |
| 1801–3500 | 4 · demanding | 6 |
| 3501–5200 | 5 · advanced | 7 |

Every tenth level is a relief puzzle with three familiar targets, no required
full-rack anchor, and a lower difficulty label. Every twenty-fifth level that
is not a relief puzzle emphasizes a less frequent learning word. A rack with
fewer available words uses its available targets. These rules establish a
testable initial curve; frequency and word length are estimates of challenge,
not measurements of a player's ability.

The delivered rack distribution is 4 three-letter racks, 343 four-letter
racks, 1,201 five-letter racks, 1,816 six-letter racks, 1,414 seven-letter racks,
and 422 eight-letter racks. Later difficulty adds vocabulary and target count
as well as rack length.

## Dictionary sources and curation

Definitions originate from **Princeton WordNet 3.0**. The build selects
lowercase alphabetic lemmas between 3 and 8 characters, excludes named-instance
senses and uppercase acronyms, and filters sensitive, derogatory, archaic,
abbreviation, and unsuitable senses. A conservative exclusion list and
frequency thresholds reduce obscure short words. Tagged usage counts select
common senses instead of blindly preferring WordNet's noun-first order.

**wordfreq 3.1.1**, by Robyn Speer, supplies English frequency estimates during
generation. Thresholds are Zipf 4.0 for three-letter words, 3.4 for four-letter
words, and 3.2 for longer words, with authored exceptions. Its frequency data
is not required by the game or by offline validation. Common plural and verb
forms are then added as bonus vocabulary when WordNet confirms a base form
already present in the dictionary; these forms do not inflate the level pool.

The generator contains authored definitions for onboarding words, grammatical
forms, and common words whose dictionary-first senses would be confusing.
WordNet definitions receive initial capitalization, final punctuation, and
normalized quotation marks. The selection, ordering, filtering, and authored
entries are modifications made for Folio.

This is a generated campaign with a curated opening, **not 5,200 manually
reviewed puzzles**. Automated checks prove formability, uniqueness, bounds,
and definition coverage; they do not prove ideal pacing, universal familiarity,
or that every dictionary sense reads naturally. WordNet is an older lexical
resource and some entries retain formal or dated wording. Broad editorial
playtesting and audience-specific vocabulary review remain release work.
The bonus dictionary is a deliberately bounded learning dictionary, not a
complete tournament or Scrabble word list. Uncommon inflections and some regional
spellings are absent.

## Validate without installing anything

From the project root:

```sh
python3 tools/build_content.py --validate
```

The validator uses only Python's standard library and performs no network
requests. It asserts consecutive IDs, exactly 5,200 puzzles, different sorted
racks, rack sizes, unique target counts, valid difficulty bounds, short opening
puzzles, defined target words, exclusion rules, and letter multiplicities.

## Rebuild reproducibly

Python 3.12 was used for the shipped build. Generator packages are optional
development tools and are not Godot or game dependencies.

```sh
python3 -m venv /tmp/folio-content-venv
/tmp/folio-content-venv/bin/pip install nltk==3.9.2 wordfreq==3.1.1
/tmp/folio-content-venv/bin/python tools/build_content.py --cache /tmp/folio-nltk
python3 tools/build_content.py --validate
```

The first build downloads the WordNet archive over verified HTTPS from:

`https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/wordnet.zip`

Both downloaded and cached archives must match this SHA-256 digest:

`cbda5ea6eef7f36a97a43d4a75f85e07fccbb4f23657d27b4ccbc93e2646ab59`

No checksum or TLS verification is disabled. The fixed generator seed is
271828. The pinned packages, verified WordNet archive, stable sorting, and
fixed seed produce byte-identical JSON on repeated runs. Rebuilding rewrites
only the two generated JSON files and the upstream WordNet license. Keep
download caches and Python environments outside the checkout.

## Attribution and licensing

WordNet 3.0 Copyright 2006 by Princeton University. All rights reserved.
The full permission notice and disclaimer are in
[`WORDNET-LICENSE.txt`](../data/licenses/WORDNET-LICENSE.txt).
WordNet is used under its permissive database license; no endorsement is
implied. The NLTK project hosts the unchanged corpus archive.

wordfreq code is Apache-2.0 and its frequency data is redistributable under
**Creative Commons Attribution-ShareAlike 4.0**. See
[`WORDFREQ-NOTICES.md`](../data/licenses/WORDFREQ-NOTICES.md) for upstream source
credits, including Google Books Ngrams, Wikipedia, Leeds Internet Corpus,
ParaCrawl, OPUS/OpenSubtitles, and the freely available SUBTLEX data by Marc
Brysbaert and collaborators. See the full notices for citations and source
links.

The Folio content compilation, generated levels, and authored dictionary
additions are provided under **CC BY-SA 4.0**, retaining the WordNet notices for
WordNet-derived text. This content license is separate from the game code's
license. Preserve source attribution and share adapted content under the same
license. See [`data/licenses/README.md`](../data/licenses/README.md).
