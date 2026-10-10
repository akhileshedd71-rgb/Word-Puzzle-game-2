# Folio: a little wordplay, a lasting vocabulary

Folio is an offline-first, portrait mobile word game made in Godot. Its central promise is simple: **find a satisfying word, discover what it means, remember it later.** The visual identity is a small independent word magazine: confident serif headlines, crisp sans-serif letters, ink rules, white space, cobalt feedback, and a precise coral accent.

This document records the research and design rationale for the playable v0.1 build. The implemented modes below are present in the project; the README and build notes describe available downloads and validation. Proposals in the final section are future work, not available features.

## What to learn from other word games

These are qualitative comparisons of familiar game formats, not claims that any mechanic guarantees retention. Official game pages are linked below for further reading; their live contents could not be checked from this environment's restricted network.

| Reference | Useful pattern | Folio interpretation |
| --- | --- | --- |
| Wordscapes / Word Connect | A small letter bank creates many discoverable words; visible slots make progress concrete. | A tactile letter wheel, explicit target lengths, immediate acceptance, and bonus discoveries. |
| Wordle | Clear constraints, readable feedback, and a shared daily puzzle create an easy-to-explain ritual. | A deterministic daily edition and a concise, spoiler-free result; the main campaign remains playable any time. |
| Spelling Bee | A compact alphabet rewards exploration beyond the first obvious answers. | Bonus words acknowledge a valid discovery even when it is outside the required target set. |
| Connections | A change in interpretation can be more interesting than a rarer word. | Definition-led play adds semantic reasoning; later editorial puzzles can explore ambiguity and associations. |
| Traditional crossword and word-ladder puzzles | Clues and intersecting constraints create a sequence of small deductions. | Learn from clue clarity and pacing; reserve full crosswords and ladders for later dedicated modes. |

The first version concentrates on a reusable letter-building interaction. It avoids presenting several shallow copies of unrelated games as a finished collection.

## The play loop

1. Read a compact goal and inspect a small bank of letters.
2. Swipe across letters or tap them in order, then submit a word.
3. Receive specific feedback: found target, new bonus word, already found, or not accepted.
4. See progress and an optional definition without interrupting the next discovery.
5. Finish the page, receive a small fixed reward, and choose another puzzle or stop.
6. Revisit collected words in a separate recall session.

The “aha” moment is a useful design description for solving a constraint. It is not a measured dopamine claim. Reward feedback should communicate success, not obscure the task with an explosion of currencies. A completed page is a natural stopping point.

## Modes and challenge identity

| Mode | Main question | Desired feeling | Boundaries |
| --- | --- | --- | --- |
| Journey | Which words can these letters make? | Steady competence and discovery | 5,200 numbered puzzles; sequential unlocks and saved progress. |
| Cozy | What else can I find at my own pace? | Calm exploration | Untimed practice; no lives or mistake penalty. |
| Clue | Which word matches this meaning? | A change of perspective | One target definition at a time; solve its matching word before the next target. |
| Sprint | How many words can I find in 90 seconds? | Voluntary intensity | Pauses when the app loses focus or a modal opens; saves a personal best. |
| Daily edition | How did I approach today's shared letters? | A brief recurring ritual | Deterministic UTC date selection within the same content version; clipboard result sharing. |
| Word recall | Can I recover the word from its meaning? | Useful learning | Immediate first-session practice, answer reveal, and self-rated spaced reviews. |

Cozy, Clue, and Sprint each offer five selectable difficulties: **Gentle, Easy, Thoughtful, Tricky, and Intense**. “Tricky” and “Intense” are difficulty choices, not additional game modes. Their puzzles come from the same bundled campaign pool, with separate progress records. Practice does not unlock campaign levels or pay repeat-clear coins.

The daily puzzle complements unlimited play. It does not remove campaign access or penalize a missed day. Its completion reward is granted once for the current UTC date; campaign rewards are also once per level. Seven daily completions count toward a milestone without requiring consecutive days. The build uses the device clock and no live service: cross-device synchronization, trusted time, and leaderboards are not present.

## A campaign beyond 5,000 levels

The shipped campaign contains **5,200 distinct letter multisets**, 5,810 distinct target words, and 10,011 dictionary entries. Its first 20 puzzles are hand-selected; subsequent puzzles are generated deterministically. See [CONTENT.md](CONTENT.md) for the exact dataset, licensing, difficulty bands, and regeneration instructions.

Quantity is a content pipeline problem as much as a UI problem. A useful generated level has a valid bank, a solvable set of targets, a known difficulty estimate, and stable identity. A shuffled copy of the same letter bank and target set is not a new puzzle.

The content validator checks:

- Every target and accepted bonus word can be made with the bank's actual letter counts. A repeated letter requires a repeated tile.
- Targets are nonempty, unique, present in the bundled lexicon, and within the supported display length.
- The campaign contains exactly 5,200 different sorted letter banks, with consecutive IDs and bounded difficulty values.
- Introductory pages use short targets and the opening content satisfies the starter constraints.
- Every target has a bundled definition. This establishes coverage; the quality and suitability of every dictionary sense still need editorial review.

The opening uses familiar words with authored meanings. Later difficulty estimates combine bank length, familiarity, repeated letters, rare letters, and target count. Every tenth page provides relief with fewer, familiar targets; selected other pages emphasize a less frequent learning word. A word list and a definitions database remain different assets with different licensing requirements.

Word frequency is a useful editorial signal, not an objective measurement of difficulty. Familiarity varies with age, region, language background, and topic. A common short word can still be difficult to see in an unfamiliar bank.

### Implemented pacing, with editorial goals

| Phase | Introduce | Keep manageable |
| --- | --- | --- |
| Opening pages | One interaction, short familiar words, quick completions | Few required targets; obvious first discoveries |
| Early journey | More letter combinations and occasional repeated letters | Gradual growth in bank size and target count |
| Middle journey | Longer targets, more competing possibilities, definition clues | Alternate demanding pages with lighter recovery pages |
| Advanced journey | Larger search spaces and less immediate associations | Fair acceptance rules, usable hints, and visible progress |

These are the goals behind the implemented generation bands, not a claim of 5,200 individually edited puzzles. Automated validation checks the content; broad human sampling remains release work. The next editorial pass should examine frustration points, repeated families, unusual senses, and vocabulary suitability. Time-to-solve, hints used, and unfamiliar-word reports are more informative than raw level number.

## Learning that involves retrieval

Displaying a definition provides an opportunity to learn; it does not establish that learning occurred. Found target and bonus words automatically enter the collection. Review counts are stored separately. Neither a collected word nor a self-rating is a verified mastery measurement.

The Words screen provides meanings, a search field, and a recall session. New discoveries are due immediately so learning can begin in the first session. Recall shows the meaning and letter count, asks the player to bring the word to mind, then reveals the answer. The two self-ratings are **I remembered** and **Let's meet again**. Successful reviews schedule the next visit after **1, 3, 7, 14, then 30 days**; subsequent successes remain at 30 days. A missed review resets the sequence and returns the word after one day. These are intervals from each review, not cumulative dates from first discovery.

This is a simple fixed interval scheduler. It does not test a typed answer, fit an individual memory model, or claim a measured retention probability. Contextual examples, more nuanced recall feedback, and adaptive scheduling are later experiments.

Research supports the direction, with limits. Settles and Meeder's 2016 Duolingo work models recall as a function of time and learning history; its results concern that model and dataset, not Folio. Anki's manual describes the practical distinction between active recall and passive rereading. These sources justify trying spaced recall, followed by actual usability and learning evaluation. They do not justify promises to prevent cognitive decline or raise intelligence.

## An editorial visual system

- **White and ink:** readable text, thin rules, decisive black headings, and a compact hierarchy.
- **Cobalt:** primary action, selection, and clear progress. Color also has a textual or shape cue.
- **Coral:** a small accent for highlights and optional intensity; not a blanket background tint.
- **Typography:** a distinctive serif for titles and a highly readable sans-serif for controls, definitions, and letters.
- **Composition:** a magazine masthead, page numbers, editorial dividers, and one dominant interaction area. Avoid a generic dashboard of identical cards.
- **Motion:** restrained fades or small tile responses that confirm an action. Reduced-motion settings should preserve all necessary feedback.
- **Mobile:** a portrait canvas, visible back navigation, and scrollable content and long definitions. Tap, swipe, and desktop keyboard input support different ways to play. Physical-device checks of touch targets, keyboard behavior, cutouts, and system navigation remain part of the playtest checklist.

Cozy comes from forgiving rules and visual clarity; it does not require beige paper, botanical imagery, or low contrast. Letterforms, geometry, and typographic illustration are the artwork. Emoji are not the primary art system.

## Rewards and customization

Coins provide a lightweight sense of progress. The local economy starts with 120 coins; journey completions award 25–45 depending on difficulty, the current daily awards 40, and Studio milestones have explicit fixed rewards. A letter hint costs 15. Free definition clues and shuffling remain available. Three optional accent inks cost 120, 180, and 240 coins, while the Paper and Midnight themes are included. Transactions persist locally and cannot spend below zero. The shop is a placeholder economy: there is no real-money checkout, ad reward, or live payment service in this build.

Cosmetics change presentation without changing accepted words or difficulty. Sound and reduced motion are implemented preferences; haptics are not implemented. There are no scarcity countdowns, random paid rewards, or punitive login mechanics.

## Roadmap and evaluation

| Stage | Scope |
| --- | --- |
| Implemented v0.1 | Godot portrait UI; 5,200 distinct generated campaign racks and curated opening; Cozy, Clue, 90-second Sprint, and UTC daily; five difficulty choices; meanings, word collection, and fixed interval recall; local persistence and backup; milestone challenges; cosmetic/hint currency prototype; Paper/Midnight, sound, and reduced motion. |
| Editorial pass | Human review of vocabulary and definitions, more distinctive puzzle families, calibrated early-game pacing, broader device and accessibility testing. |
| Later experiments | Hand-authored semantic mini-packs, word ladders, clue crosswords, richer contextual examples, optional archive, and a research-based adaptive recall scheduler. |
| Separate product work | Physical Android/iOS validation, a signed iOS build, native sharing polish, opt-in account sync, localization, store publication, and monetization decisions. |

Useful playtest questions: Does a first-time player understand the wheel without explanation? Is a rejected word understandable? Does the next clue feel fair? Can the player stop after one page? Does recall help the player remember meanings a week later? Measure these before optimizing session length or claiming an “addictive” formula.

## Sources and verification notes

Primary sources inspected on 10 October 2026 through their official GitHub repositories:

1. **Settles, B., and Meeder, B. (2016). _A Trainable Spaced Repetition Model for Language Learning._ ACL, 1848–1858.** [Official Duolingo repository](https://github.com/duolingo/halflife-regression) and [paper PDF](https://github.com/duolingo/halflife-regression/blob/master/settles.acl16.pdf). The paper and repository were read; Folio does not implement HLR.
2. **Anki manual: Background.** [Official manual source](https://github.com/ankitects/anki-manual/blob/main/src/background.md). Explains active recall and spaced repetition as distinct practices.
3. **Free Spaced Repetition Scheduler for Anki.** [Official project](https://github.com/open-spaced-repetition/fsrs4anki). Describes a scheduler plus an optimizer trained on review history. A possible later reference, not a current Folio dependency or performance claim.
4. **wordfreq documentation.** [Author's repository](https://github.com/rspeer/wordfreq). Documents Zipf frequency, multi-corpus sources, limitations, and the historical nature of the data. Relevant to generation and familiarity estimates.
5. **Wordnik Wordlist.** [Official repository](https://github.com/wordnik/wordlist). Its README explicitly distinguishes the open word list from a separately licensed dataset containing meanings and other metadata. Listed as a content-licensing lesson, not as a claim that Folio uses Wordnik data.

Game-format reference links, **not live-verified during this build** because their hosts are outside the environment's allowed network destinations: [PeopleFun Wordscapes](https://www.peoplefun.com/games/wordscapes), [NYT Wordle](https://www.nytimes.com/games/wordle/index.html), [NYT Spelling Bee](https://www.nytimes.com/puzzles/spelling-bee), and [NYT Connections](https://www.nytimes.com/games/connections). No proprietary puzzles, word lists, screenshots, or game artwork were copied from these products.
