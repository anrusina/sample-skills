# Dependency check

Used by `/commit` step 4 whenever a package manifest gains a new dependency.
This file is the language-neutral procedure. The registry commands, the
record's form and any stack-specific policy are in the *Dependency registry*
section of the loaded stack asset.

The **policy** (thresholds, what counts as unusual, where records live) comes
from the `dependency policy` fact. Without one, the default is: the exact
version being added was published at least 14 days ago, its source repository
shows no unusual recent activity, and the check is recorded next to the
dependency.

The commands use `jq`. Replace `<name>`, `<x.y.z>` and the other angle slots
with the package being added.

## 1. Find the publish date and the source repository

Use the loaded stack asset's *Dependency registry* row for the manifest in the
diff.

With no stack asset for that manifest, look up the registry's public API for
the publish date of the exact version and the package's source repository. If
you can't find it reliably, do not guess: ask the developer once how to find
both, and use the answer. Either way, propose to the developer a stack asset
for that registry (`assets/stack/<id>.md` with a *Dependency registry*
section) so the next run doesn't have to look it up.

A private registry or mirror configured for the project (an `.npmrc`,
`pip.conf`, Cargo `config.toml`, `GOPROXY`, Maven `settings.xml`) may serve a
different copy; when one is configured, check the public registry the package
actually comes from and say which one you used.

## 2. Assess the source repository

For a GitHub repository:

```bash
gh api repos/<owner>/<repo> --jq '{pushed_at, updated_at, archived}'
gh api "repos/<owner>/<repo>/commits?per_page=10" \
  --jq '.[] | {date: .commit.author.date, author: .author.login, subject: (.commit.message | split("\n")[0])}'
gh api "repos/<owner>/<repo>/contributors?per_page=10" --jq '.[].login'
```

Here `<owner>/<repo>` is the dependency's repository, written in literally,
not this project's.

(`curl -s https://api.github.com/repos/<owner>/<repo>/...` returns the same
data unauthenticated, at a lower rate limit.)

For GitLab: `curl -s "https://gitlab.com/api/v4/projects/<url-encoded owner%2Frepo>/repository/commits?per_page=10"`.
Other hosts: use their web history page or API; if it can't be assessed, stop.

Signals that fail the check:

- a burst of commits or releases after a long quiet period
- commits or the release itself made by an account not seen before among the
  maintainers, or a recent ownership transfer
- new install-time hooks or build scripts (npm `preinstall`/`postinstall`,
  `setup.py` side effects, `build.rs` network access)
- the repository is archived, deleted, or does not match the registry's
  published source

## 3. Record the check

Write the record directly above the dependency line, in the manifest's own
comment syntax (the stack asset gives it), and stage it with the dependency
change:

```
Checked <today>: published <date>, active maintenance, no unusual activity
```

A manifest that cannot hold comments (plain JSON, such as `package.json` or
`composer.json`) gets the record wherever the dependency policy says. If it
says nothing, ask the developer once where such records live (a
`docs/dev/dependencies.md` table is a common choice), use the answer, and tell
them to record that place in the dependency policy. Mention the check in the
commit body's `Work done:` as well.
