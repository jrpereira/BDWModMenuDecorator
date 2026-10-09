# Module categories

MCS scans installed UE4SS mod folders once during startup and writes
`cache/modules_register.json`. MCS's DMM extension reads that JSON file when
building the browser. Category data does not use shared variables.

The authoritative taxonomy is `data/mod_categories.json`. Packaging generates
`Scripts/mcs_taxonomy_data.lua`, the runtime fingerprint database and the Unicode
normalizer with `tools/build_mod_fingerprints.py`. Development tools, research and
tests stay outside the installed payload.

## Author declarations

Declare the browser metadata in a mod folder's `mod.txt`:

```text
author: 'Example Author',
browser: {
    preferred: author,
    categories: {'gear', 'appearance'},
    tags: {'fix', 'compatibility'},
    icon: {utf8: '♞'}
}
```

This is a data-only format: colon-separated fields, quoted strings, brace lists,
nested objects, optional trailing commas and `--` line comments. Scripts and
expressions are rejected. `preferred: author` needs a declared author. A quoted
preferred value names a custom group or a canonical category. The equivalent
`browser` object is also supported in `mod.json`; `mod.txt` takes precedence.

Select up to three substantial categories, in any combination. Selecting both a
parent and its child does not consume two slots. Parent membership is derived;
no primary category is needed. Tags are separate and do not consume category
slots. Duplicate and unknown identifiers are rejected. There are no aliases:
`transport` is canonical; `vehicles` and `combat` are not accepted categories.

| Parent | Selectable children |
|---|---|
| Gameplay (`gameplay`) | `action`, `progression`, `movement`, `economy`, `survival`, `behaviour` |
| Content (`content`) | `gear`, `items`, `characters`, `world`, `quests`, `transport` |
| Presentation (`presentation`) | `interface`, `appearance`, `visuals`, `audio`, `camera` |
| Technical & Support (`support`) | `frameworks`, `performance`, `tools`, `translations` |
| Other or Specialized (`other`) | Fallback with a specialized, insufficient-evidence or ambiguous reason |

Tags: `experimental`, `broad`, `adult`, `accessibility`, `cheat`, `fix`,
`compatibility`. An absent tag is not a verified negative. The classifier never
assigns tags from uncertainty, body filenames or generic helper code.

## Identification and classification

Declared categories take precedence. For undeclared modules, fingerprint
matching records identity candidates separately: module links outrank structural
clues and names, author alone is insufficient, and conflicting authors reject
non-link candidates. A match can supply explicitly reviewed catalog categories;
raw source-platform category labels are not automatically transferred.

If no reviewed assignment is available, the Lua source scanner supplies tentative
category selections and retains evidence paths and terms. Its rules exclude
setup UI and common settings helpers. Source text can contain comments or string
literals, so these are clues rather than proof of behavior. More than three
inferred categories abstain. With insufficient evidence the module uses `other`.
No inspected module's code is executed. Shared-directory Pak installations are
outside this folder scan.

## Index and migration

The index uses `schema_version: 2`, `taxonomy_version: 2`, and a `modules` object
keyed by installed folder. Each entry records `categories`, derived `parents`,
`tags`, optional `preferred` and `icon`, classification `source` and `confidence`,
and identity candidates/evidence where available. Fallback entries retain a
`reason` of `specialized`, `insufficient_evidence` or `ambiguous`.

Successful entries remain cached, including `other`. Delete a specific entry to
request classification again after changing author declarations. Malformed or
unreadable declarations are logged and left uncached for the next startup.
Legacy single-category caches are reclassified; their custom preferred group is
preserved. Obsolete category labels are not converted through aliases.

Writes use a temporary file followed by replacement. The DMM reader retains its
last valid snapshot if the index is temporarily absent or invalid. An index error
does not prevent the settings integration from loading.

## Browser behavior

The default browser displays populated parent sections. A module appears once
per applicable parent; placements reuse the same provider and settings. Children
stay with their parent page. Module totals and preferred-group thresholds count
distinct folders, not placements or settings pages. Foundation pages retain their
ModCore grouping.

Group modules and Preferred Category valid with # modules retain their existing
settings in `config.ini` under `[Modules]`. A preferred author/custom/category
group replaces parent placements only when its distinct-folder threshold is met;
otherwise the module uses its taxonomy parents. No disables preferred grouping.
Disabling module grouping lists each page once.

`page:setCategoryFilter(ids, 'any'|'all')` and
`page:setTagFilter(ids, 'any'|'all')` filter independently. The two filters combine
with AND and also respect the existing compatible-only filter. These are browser
API methods; no additional filter controls or density thresholds are introduced.
Parent sections are not subdivided automatically.
