# omikhleia-sile-packages

Packages and classes for the SILE typesetter

I wanted to give a try to the [SILE](https://github.com/sile-typesetter/sile) typesetting system. If I had to typeset a book, however, the version of SILE at the time (that was 0.10.15 at the initial time of writing) lacked many supporting packages for the sort of things I usually write.

This repository is the result of my attempt at providing the packages and classes that would
fit my needs.

The [PDF documentation](./docs/omikhleia-packages.pdf) serves both as documentation and as
main showcase. A few other examples are provided too.

## August 2022 Deprecation Notice

_This repository is pending deprecation._

One year after its inception, more or less, it's time to move on, re-assuming what we achieved and expanding the
vision in new directions.

Release 1.1.0 from August 17, 2022 is therefore likely the last one here. Unless some people still using SILE v0.12
for any reasons want to give it a shot, but meet unexpected issues, I have no plan for upgrading this repository.
At best, it may receive bug-fixes, in "maintenance mode" only, until its probable archiving.

Development towards a v2.0 is ongoing in a [new repository](https://github.com/Omikhleia/resilient.sile), targetting SILE v0.14 or
upper and using the new package management for SILE introduced in v0.13 (based on **luarocks**), which is a great addition and
will surely help package and class designers to distribute their work and spread the word. Alerque _et al._ did a great job
there.

I'd like to thank all those who visited this repository, followed it or starred the project. Even if you were few,
and many didn't even say a word, hey, it's always nice to see other minds possibly interested in similar things.
You all rock! - And are obviously welcome on the new repository too. 

## Prerequisites

The packages, classes and examples provided here currently require SILE **v0.12.5**.

- They rely on a number of fixes introduced in earlier releases and are therefore
  not guaranteed to still work with anything older than this version.
- They sometimes rely on low-level "hacks" or workarounds to avoid issues present in that release.
  (That's especially true for examples, a bit less for packages and classes.)
- Breaking changes are to be expected in later releases...

The packages and classes provided here are tested with Lua **5.2**.

- SILE uses the version of Lua installed on your host system, and other Lua versions
  may have different behaviors (regarding type casts, etc.).
- Lua 5.2 was my current setup for the developments, and the time or effort to check each Lua version
  from 5.1 to 5.4, JIT-enabled or not, was not within my concerns.

## License

All code is under the MIT License.

The documentation is under CC-BY-SA 2.0.

The examples (i.e. anythings in the "examples" folder) have varying licenses and some are
used by courtesy of the authors. Please refere to the [README](./examples/README.md) in that
folder for details and exact licensing terms.
