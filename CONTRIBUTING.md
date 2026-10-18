# Contributing

Every contribution is licensed under the project's [MIT licence](LICENSE).

## Pull requests

- Link an issue or describe the change in a few lines.
- Comment code that spans several files or needs more than basic knowledge to follow.
- Follow the indentation of the surrounding code.
- Run `bats tests/` and the lint command in [README.md](README.md#development) before opening the request.
- A change to a flag, variable or output field updates the bash and PowerShell halves, the help texts, [man/up.1](man/up.1), [doc/documentation.tex](doc/documentation.tex), the completions and the README together.

## Rejected contributions

- Links or references to servers the project does not own.
- Code that exposes users to vulnerabilities or bypasses privileges.
- Code that discriminates against people or serves a crime.

## Code under another licence

Code you did not write is accepted only if its licence permits inclusion in an MIT project. State its author and licence in the pull request and in [reference/third-party.md](reference/third-party.md).
