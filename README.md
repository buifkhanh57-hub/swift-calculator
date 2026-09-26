# unitwise

**Precise unit conversion from the terminal — one Swift binary, zero dependencies.**

![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)
![Tests](https://img.shields.io/badge/tests-XCTest%20%2B%20selftest-orange)
![Version](https://img.shields.io/badge/version-1.0.0-lightgrey)

---

## Overview

`unitwise` is a dependency-free command-line unit converter written in pure
Swift 5.9. It parses everyday expressions such as `5 km to mi`, `72 f to c`,
or `3.5 MB in MiB`, resolves them against a registry of **10 categories and
129 units**, and prints results with a configurable number of significant
figures.

It is built the old-fashioned way: only the Swift standard library and
Foundation, no third-party packages, no code generation, no network access.
The whole conversion pipeline (parser → resolver → engine → formatter) lives
in one executable target, which keeps the build graph trivial and makes the
binary trivially auditable.

Highlights:

- Natural expression syntax with the category inferred automatically
- Case-sensitive alias handling (`MB` = megabyte, `mb` = megabit)
- Affine temperature scales that convert through kelvin
- Decimal vs. binary data sizes with a `--base2` remap switch
- CSV batch processing with per-row error reporting
- A JSON output mode for scripting and piping
- A persistent, local conversion history

## Features

| Feature | Description |
|---|---|
| **10 categories** | Length, Mass, Temperature, Volume, Speed, Data Size, Time, Energy, Pressure, Area |
| **129 units** | From ångströms to parsecs, nanoseconds to millennia, bits to pebibytes |
| **Alias resolution** | Exact-case → case-insensitive → plural-stripped lookup (`5 KM TO MI` works) |
| **Temperature anchors** | Freezing/boiling points hold in every direction via affine mapping |
| **Data-size semantics** | `kB` = 1000 B by default; `--base2`/`--iec` reads loose tokens as KiB-style |
| **Significant figures** | `--digits 1...15`, default 6; stable formatting, no libm dependency |
| **N×N tables** | Every unit of a category converted against every other at one value |
| **Batch CSV** | Rows of `value,from,to` (or single expressions); failed rows reported, never aborted |
| **JSON output** | `--json` for convert, list, and history — pipe straight into `jq` |
| **History** | Successful conversions recorded to `~/.unitwise/history.json`; list, trim, clear |
| **Self-test** | `unitwise selftest` runs built-in sanity checks without needing XCTest |
| **Clean errors** | Every failure prints a message *and* a fix-it hint; documented exit codes |

## Requirements

- **Swift 5.9** or newer (the package uses `swift-tools-version:5.9`)
- **macOS 12+** or any Linux distribution with a Swift toolchain
- ~10 MB of disk for the build
- No other dependencies — there are none to install

## Installation

Clone (or copy) the project directory and build from source:

```console
$ cd unitwise
$ swift build -c release
```

The binary lands at `.build/release/unitwise`. Copy it anywhere on your
`PATH`:

```console
$ cp .build/release/unitwise /usr/local/bin/
```

For development, run straight through the package manager:

```console
$ swift run unitwise 5 km to mi
```

## Quick Start

```console
$ swift run unitwise 5 km to mi
5 km = 3.10686 mi

$ swift run unitwise 72 f to c
72 °F = 22.2222 °C

$ swift run unitwise 3.5 MB to kB
3.5 MB = 3500 kB

$ swift run unitwise --base2 3.5 MB to kB
3.5 MB = 3670.02 kB

$ swift run unitwise list
unitwise categories (10)
  length       18  Distances from ångströms to parsecs.
  mass         14  Weights from micrograms to long tons, metric and imperial.
  temperature   8  Offset-correct temperature scales from kelvin to rømer.
  volume       16  Liters, cubic measures, and US/imperial kitchen units.
  speed         7  Velocities from knots to the speed of light.
  datasize     16  Bits, decimal bytes (kB = 1000), and binary bytes (KiB = 1024).
  time         14  Durations from nanoseconds to millennia.
  energy       13  Work and heat from electronvolts to megawatt-hours.
  pressure     12  Force per area from pascals to kips per square inch.
  area         11  Surfaces from square millimeters to square nautical miles.
run 'unitwise list <category>' for a unit table.
```

Verbose mode adds the round-trip check and exactness verdict:

```console
$ swift run unitwise --verbose --digits 8 5 km to mi
5 km = 3.10685596 mi
  via m: 5000 · round-trip 5 km · exact
```

## Usage

### Command reference

| Command | Aliases | Syntax | Description |
|---|---|---|---|
| `convert` (default) | `c`, `conv`, `cv` | `unitwise [convert] VALUE FROM to TO` | One-shot conversion; the command word is optional |
| `list` | `ls`, `cats` | `unitwise list [CATEGORY]` | Category overview, or one category's unit table |
| `table` | `tbl`, `grid` | `unitwise table CATEGORY [VALUE]` | N×N conversion matrix at a value (default 1) |
| `batch` | `b`, `csv` | `unitwise batch --in FILE [--out FILE]` | Convert a CSV; exit 3 if any row fails |
| `history` | `hist`, `log` | `unitwise history [--limit N] [--clear]` | Show, trim, or erase the conversion history |
| `help` | `h`, `-h`, `--help` | `unitwise help` | Full manual |
| `version` | `ver`, `-V`, `--version` | `unitwise version` | Print `unitwise 1.0.0` |
| `selftest` | `test`, `self-check` | `unitwise selftest` | Run the built-in sanity checks |

### Flags

| Flag | Effect |
|---|---|
| `--digits N` | Significant figures for results (1...15, default 6) |
| `--to UNIT` | Give the target unit outside the expression |
| `--json` | Machine-readable output (convert, list, history) |
| `--base2`, `--iec` | Read loose data tokens (`MB`, `GB`…) as binary MiB-style |
| `--decimal` | Read loose data tokens as decimal MB-style (default) |
| `--verbose` | Extra detail: base value, round-trip, exactness |
| `--in FILE` | Batch input (`-` reads standard input) |
| `--out FILE` | Batch output (default: standard output) |
| `--header` | Batch input's first row is a header; emit one back |
| `--limit N` | Number of history rows to show |
| `--clear` | Erase the history file |
| `--no-history` | Convert without recording to history |

### Realistic terminal sessions

Convert with JSON output for scripting:

```console
$ swift run unitwise --json 2.5 mi to km
{
  "expression": "2.5 mi to km",
  "category": "length",
  "input": { "value": 2.5, "unit": "mi" },
  "result": { "value": 4.02336, "unit": "km", "formatted": "4.02336" },
  "base": { "value": 4023.36, "unit": "meter" },
  "roundTrip": 2.5,
  "exact": true
}
```

Build an N×N matrix for a category:

```console
$ swift run unitwise table speed 1
1 m/s — Speed conversion matrix
unit    m/s     km/h    mph     kn      ft/s    M       c
m/s     1       3.6     2.23694 1.94384 3.28084 0.00291545 3.33564e-09
km/h    0.277778 1      0.621371 0.539957 0.911344 0.000809847 2.77778e-10
...
```

Batch-convert a CSV with a header row:

```console
$ cat lengths.csv
value,from,to
5,km,mi
100,f,c
10,bogus,mi

$ swift run unitwise batch --in lengths.csv --header
line,input,from,to,result,status,error
2,5,km,mi,3.10686,ok,
3,100,f,c,37.7778,ok,
4,10,bogus,mi,,fail,unknown unit 'bogus' in category 'length'
batch: 2 of 3 rows converted, 1 failed
unitwise: error: batch had 3 rows, 1 failed
```

(The summary goes to stderr, the CSV to stdout — safe to redirect. The exit
code is `3` because at least one row failed.)

Inspect and trim the history:

```console
$ swift run unitwise history --limit 3
when                 category     expression       result
2025-01-15T09:12:04Z length       5 km to mi       3.10686 mi
2025-01-15T09:12:31Z temperature 72 f to c        22.2222 °C
2025-01-15T09:13:07Z datasize     3.5 MB to kB     3500 kB
```

Recover from a typo — the error always carries a hint:

```console
$ swift run unitwise 5 kilomiters to mi
unitwise: error: unknown unit 'kilomiters' (expression: '5 kilomiters to mi')
unitwise: hint: did you mean 'kilometer'? unitwise list length shows every unit
```

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Usage error — bad flags, unknown command/category |
| `2` | Conversion error — bad expression, unknown/ambiguous unit |
| `3` | Partial batch failure — at least one CSV row failed |
| `4` | I/O error — unreadable input, unwritable output |
| `70` | Internal config error — registry invariants violated |

## Category & Unit Reference

Every table below is generated from the actual unit lists in
`Sources/UnitWise/Categories/` — 129 units across 10 categories.

### Length — base meter (m), 18 units

| Symbol | Name | | Symbol | Name |
|---|---|---|---|---|
| `m` | meter | | `mi` | mile |
| `km` | kilometer | | `nmi` | nautical mile |
| `cm` | centimeter | | `ly` | light-year |
| `mm` | millimeter | | `AU` | astronomical unit |
| `µm` | micrometer | | `pc` | parsec |
| `nm` | nanometer | | `Å` | ångström |
| `dm` | decimeter | | `ftm` | fathom |
| `in` | inch | | `fur` | furlong |
| `ft` | foot | | `yd` | yard |

### Mass — base kilogram (kg), 14 units

| Symbol | Name | | Symbol | Name |
|---|---|---|---|---|
| `kg` | kilogram | | `lb` | pound |
| `g` | gram | | `oz` | ounce |
| `mg` | milligram | | `st` | stone |
| `µg` | microgram | | `ton` | short ton |
| `t` | tonne | | `longton` | long ton |
| `ct` | carat | | `gr` | grain |
| `slug` | slug | | `Da` | dalton |

### Temperature — base kelvin (K), 8 units

All scales convert through kelvin with affine mapping
(`base = value·scale + offset`), so freezing/boiling anchors hold in every
direction.

| Symbol | Name |
|---|---|
| `K` | kelvin |
| `°C` | celsius |
| `°F` | fahrenheit |
| `°R` | rankine |
| `°De` | delisle |
| `°N` | newton degree |
| `°Ré` | réaumur |
| `°Rø` | rømer |

### Volume — base liter (L), 16 units

| Symbol | Name | | Symbol | Name |
|---|---|---|---|---|
| `L` | liter | | `gal` | US gallon |
| `ml` | milliliter | | `impgal` | imperial gallon |
| `m3` | cubic meter | | `qt` | quart |
| `cm3` | cubic centimeter | | `pt` | pint |
| `in3` | cubic inch | | `cup` | cup |
| `ft3` | cubic foot | | `floz` | fluid ounce |
| `tbsp` | tablespoon | | `impfloz` | imperial fluid ounce |
| `tsp` | teaspoon | | `bbl` | oil barrel |

### Speed — base meter per second (m/s), 7 units

| Symbol | Name |
|---|---|
| `m/s` | meter per second |
| `km/h` | kilometer per hour |
| `mph` | mile per hour |
| `kn` | knot |
| `ft/s` | foot per second |
| `M` | mach |
| `c` | speed of light |

### Data Size — base bit (b), 16 units

Decimal bytes (`kB = 1000 B`) and binary bytes (`KiB = 1024 B`) coexist.
Loose tokens such as `MB` are read decimal-style by default; `--base2`
switches them to the binary interpretation.

| Symbol | Name | | Symbol | Name |
|---|---|---|---|---|
| `b` | bit | | `kB` | kilobyte |
| `B` | byte | | `MB` | megabyte |
| `kbit` | kilobit | | `GB` | gigabyte |
| `Mbit` | megabit | | `TB` | terabyte |
| `Gbit` | gigabit | | `PB` | petabyte |
| `Tbit` | terabit | | `KiB` | kibibyte |
| `MiB` | mebibyte | | `GiB` | gibibyte |
| `TiB` | tebibyte | | `PiB` | pebibyte |

### Time — base second (s), 14 units

| Symbol | Name | | Symbol | Name |
|---|---|---|---|---|
| `s` | second | | `wk` | week |
| `ms` | millisecond | | `fortnight` | fortnight |
| `µs` | microsecond | | `mo` | month |
| `ns` | nanosecond | | `yr` | year |
| `min` | minute | | `decade` | decade |
| `h` | hour | | `century` | century |
| `d` | day | | `millennium` | millennium |

### Energy — base joule (J), 13 units

| Symbol | Name | | Symbol | Name |
|---|---|---|---|---|
| `J` | joule | | `Wh` | watt-hour |
| `kJ` | kilojoule | | `kWh` | kilowatt-hour |
| `MJ` | megajoule | | `MWh` | megawatt-hour |
| `cal` | calorie | | `BTU` | British thermal unit |
| `kcal` | kilocalorie | | `ftlb` | foot-pound |
| `eV` | electronvolt | | `thm` | therm |
| `hph` | horsepower-hour | | | |

### Pressure — base pascal (Pa), 12 units

| Symbol | Name | | Symbol | Name |
|---|---|---|---|---|
| `Pa` | pascal | | `atm` | standard atmosphere |
| `hPa` | hectopascal | | `Torr` | torr |
| `kPa` | kilopascal | | `mmHg` | millimetre of mercury |
| `MPa` | megapascal | | `inHg` | inch of mercury |
| `bar` | bar | | `psi` | pound per square inch |
| `mbar` | millibar | | `ksi` | kip per square inch |

### Area — base square meter (m²), 11 units

| Symbol | Name |
|---|---|
| `m²` | square meter |
| `km²` | square kilometer |
| `ha` | hectare |
| `ac` | acre |
| `ft²` | square foot |
| `in²` | square inch |
| `yd²` | square yard |
| `mi²` | square mile |
| `cm²` | square centimeter |
| `mm²` | square millimeter |
| `nmi²` | square nautical mile |

## Project Structure

```text
unitwise/
├── Package.swift                  # manifest: executable "unitwise" + test target
├── README.md                      # this file
├── Sources/
│   └── UnitWise/
│       ├── main.swift             # CLI front-end: dispatch table, flags,
│       │                          #   help text, error reporting, bootstrap
│       ├── Core/
│       │   ├── Category.swift     # Category model + CategoryRegistry + UnitResolver
│       │   ├── Unit.swift         # Unit model: linear/affine scales, aliases, tags
│       │   ├── Converter.swift    # ConversionEngine: evaluate + N×N matrix
│       │   ├── Parser.swift       # ExpressionParser: tokens, "to"/"in", Levenshtein
│       │   ├── Formatter.swift    # ResultFormatter + TableFormatter + NumberText
│       │   ├── Batch.swift        # BatchProcessor: CSV in/out, per-row failures
│       │   ├── History.swift      # HistoryStore + HistoryEntry (~/.unitwise)
│       │   ├── Errors.swift       # UnitWiseError enum with hints + exit codes
│       │   └── SelfTest.swift     # built-in checks behind `unitwise selftest`
│       └── Categories/            # one file per measurement kind
│           ├── Length.swift       #   18 units, base m   (exact agreed factors)
│           ├── Mass.swift         #   14 units, base kg
│           ├── Temperature.swift  #    8 units, base K   (affine scales)
│           ├── Volume.swift       #   16 units, base L
│           ├── Speed.swift        #    7 units, base m/s
│           ├── DataSize.swift     #   16 units, base b   (decimal + binary)
│           ├── Time.swift         #   14 units, base s
│           ├── Energy.swift       #   13 units, base J
│           ├── Pressure.swift     #   12 units, base Pa
│           └── Area.swift         #   11 units, base m²
└── Tests/
    ├── UnitWiseTests.swift        # primary XCTest suite + PlainSelfTestRunner
    └── IntegrationTests.swift     # round trips, factors, formatters, batch, CLI
```

## Architecture

The pipeline is a straight line, and every stage is a standalone type that
can be exercised from tests:

```text
argv ──▶ main.swift (dispatch + Options.parse)
          │
          ├─ convert ─▶ ExpressionParser ─▶ UnitResolver ─▶ ConversionEngine ─▶ ResultFormatter
          │              (Core/Parser)     (Core/Category)  (Core/Converter)   (Core/Formatter)
          │
          ├─ list/table ─▶ CategoryRegistry ─▶ TableFormatter
          ├─ batch ──────▶ BatchProcessor ─▶ parser/engine per row
          ├─ history ────▶ HistoryStore (~/.unitwise/history.json)
          └─ selftest ───▶ SelfTest.runAll() (Core/SelfTest)
```

Key decisions:

- **Single executable target.** Core and Categories compile into the binary;
  tests may still `import UnitWise` because Swift 5.5+ allows test targets to
  depend on executable targets.
- **Three-stage alias lookup.** Exact-case match first (so `MB` ≠ `mb`),
  then case-insensitive, then plural-stripped (`kilometers → kilometer`,
  `centuries → century`). `µ` is normalized to `u` before lookup so `µm`
  and `um` both resolve.
- **Affine scales for temperature.** Each scale carries
  `(factor, offset)` relative to kelvin; the engine composes them, which is
  why freezing and boiling anchors hold in every direction.
- **Byte-stable output.** JSON is assembled by hand, numbers are formatted
  by a pure-Swift significant-figure routine that avoids `log10`, so output
  is identical on macOS and Linux.
- **Registry validation at boot.** Duplicate ids, missing base units,
  zero/non-finite factors, and empty alias lists abort with exit code 70
  instead of producing wrong answers.
- **Error messages with hints.** `UnitWiseError` carries a `hint` plus the
  exit code, and Levenshtein suggestions offer the closest unit or category.

## Testing

Two test files cover the pipeline from both ends:

```console
$ swift test
Test Suite 'All tests' passed
```

- **`Tests/UnitWiseTests.swift`** — registry invariants, the `Unit` model,
  temperature offsets, binary vs. decimal data sizes and the `--base2`
  remap, parser aliases, plural stripping, `µ` normalization, and numeric
  anchors. It also ships `PlainSelfTestRunner`, a non-XCTest entry point for
  systems without a usable XCTest.
- **`Tests/IntegrationTests.swift`** — round trips, newer category factors,
  formatters, batch processing, history, and CLI plumbing.

Without any test runner at all, the binary self-checks itself:

```console
$ swift run unitwise selftest
42/42 self-checks passed
```

## FAQ

**Why another unit converter?**
Because most either hardcode a handful of units, or pull in a dependency
chain for what is arithmetic. `unitwise` is one auditable Swift target with
129 units, exact factors, and documented exit codes — nothing else.

**How does `unitwise 5 km to mi` work without a `convert` keyword?**
The first token is checked against the command table; anything unrecognized
is treated as the start of a convert expression, so the keyword is optional.

**Is `MB` the same as `Mb`?**
No — and that is deliberate. Alias lookup is exact-case first: `MB` is a
megabyte, `Mb` (or `mb`) is a megabit. Use `--base2` if you want loose
tokens like `MB` to be read as binary (MiB-style) instead.

**Can temperatures go negative or below absolute zero?**
Negative inputs convert fine; a result below 0 K is rejected as a
conversion error, because that answer would be physically meaningless.

**Where is the history stored?**
`~/.unitwise/history.json` — a plain JSON array, newest last. `--clear`
erases it, `--limit N` trims the view, `--no-history` skips recording for a
single call.

**Does it need the network?**
Never. No updates are fetched, no telemetry exists, and the build itself
has zero third-party packages.

**Can I add a unit?**
Yes — append a `Unit.linear(...)` (or `.affine` for temperatures) entry in
the matching `Categories/*.swift` file with an id, symbol, names, factor,
and aliases. The registry validates it on the next build.

## Roadmap

- [ ] `--from` flag mirroring `--to` for scripted pipelines
- [ ] Expression arithmetic on the input side (`5 km + 2 mi to ft`)
- [ ] Currency category with an offline, user-supplied rates file
- [ ] Shell completion scripts (bash, zsh, fish)
- [ ] A `Homebrew` formula and prebuilt Linux binaries
- [ ] Compound units (m/s², kW·h) in the parser
- [ ] `unitwise interactive` REPL mode

## License

MIT License.

Copyright (c) 2025 Bui Bao Khanh

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

---
**by Bui Bao Khanh**
