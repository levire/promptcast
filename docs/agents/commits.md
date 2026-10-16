# Commits

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `type(scope): subject`. The `commit-msg` hook checks the first line.

Types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`.

The scope is the target the change belongs to: `core` for `PromptCastCore`, `app` for `PromptCast`. A change that neither owns has no scope.

The subject completes "this commit will ...": imperative, lowercase, no full stop, the whole line under 72 characters. The body says why.

```
feat(app): stop a recording from the overlay pill
chore: pin the Xcode version in CI
```
