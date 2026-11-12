# Dependency check — registry lookups

Used by `/commit` step 4 whenever a package manifest gains a new dependency.
This file is the generic default; a project tailors it to its own ecosystem by
editing it.

The **policy** (thresholds, what counts as unusual) comes from AGENTS.md
*Security → Dependency policy*. Without one, the default is: the exact version
being added was published at least 14 days ago, its source repository shows no
unusual recent activity, and the check is recorded next to the dependency.

The commands below use `jq`. Replace `<name>`, `<x.y.z>` and the other angle
slots with the package being added.

## 1. Find the publish date and the source repository

| Ecosystem | Manifest | Publish date of `<x.y.z>` | Source repository |
|---|---|---|---|
| npm | `package.json` | `curl -s https://registry.npmjs.org/<name> \| jq -r '.time["<x.y.z>"]'` | `curl -s https://registry.npmjs.org/<name> \| jq -r '.repository.url // .homepage'` |
| PyPI | `pyproject.toml`, `requirements*.txt` | `curl -s https://pypi.org/pypi/<name>/<x.y.z>/json \| jq -r '.urls[0].upload_time_iso_8601'` | `curl -s https://pypi.org/pypi/<name>/json \| jq '.info.project_urls'` (look for Source / Repository / Homepage) |
| crates.io | `Cargo.toml` | `curl -s -A "dependency-check" https://crates.io/api/v1/crates/<name>/<x.y.z> \| jq -r '.version.created_at'` | `curl -s -A "dependency-check" https://crates.io/api/v1/crates/<name> \| jq -r '.crate.repository'` |
| pub | `pubspec.yaml` | `curl -s https://pub.dev/api/packages/<name> \| jq -r '.versions[] \| select(.version == "<x.y.z>") \| .published'` | same response: `jq -r '.latest.pubspec.repository // .latest.pubspec.homepage'` |
| Maven Central | `pom.xml`, `build.gradle*` | `curl -sI https://repo1.maven.org/maven2/<group/as/path>/<artifact>/<x.y.z>/<artifact>-<x.y.z>.pom \| grep -i '^last-modified'` | the same `.pom` without `-I`: the `<scm><url>` element (fall back to `<url>`) |
| Go modules | `go.mod` | `curl -s https://proxy.golang.org/<module>/@v/<vX.Y.Z>.info \| jq -r '.Time'` | usually the module path itself (`github.com/<owner>/<repo>`); for a vanity path, `curl -s "https://<module>?go-get=1"` and read the `go-import` meta tag |
| RubyGems | `Gemfile`, `*.gemspec` | `curl -s https://rubygems.org/api/v1/versions/<name>.json \| jq -r '.[] \| select(.number == "<x.y.z>") \| .created_at'` | `curl -s https://rubygems.org/api/v1/gems/<name>.json \| jq -r '.source_code_uri // .homepage_uri'` |

Notes:

- crates.io refuses requests without a `User-Agent`, hence `-A`.
- Go module paths with capital letters are escaped in proxy URLs: each
  uppercase letter becomes `!` plus its lowercase form
  (`github.com/Azure/x` → `github.com/!azure/x`).
- Maven group IDs become paths by replacing `.` with `/`
  (`org.example.auth` → `org/example/auth`).
- A private registry or mirror configured for the project (an `.npmrc`,
  `pip.conf`, Cargo `config.toml`, `GOPROXY`, Maven `settings.xml`) may serve a
  different copy; when one is configured, check the public registry the
  package actually comes from and say which one you used.

**Unknown ecosystem.** If the manifest belongs to an ecosystem not in this
table and its registry's API is not something you can find reliably, do not
guess. Ask the developer once how to find the publish date and source
repository, use the answer, and tell them to add a row to this file so the
next run doesn't ask.

## 2. Assess the source repository

For a GitHub repository:

```bash
gh api repos/<owner>/<repo> --jq '{pushed_at, updated_at, archived}'
gh api "repos/<owner>/<repo>/commits?per_page=10" \
  --jq '.[] | {date: .commit.author.date, author: .author.login, subject: (.commit.message | split("\n")[0])}'
gh api "repos/<owner>/<repo>/contributors?per_page=10" --jq '.[].login'
```

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
comment syntax, and stage it with the dependency change:

| Manifest | Record |
|---|---|
| `pyproject.toml`, `Cargo.toml`, `requirements*.txt`, `Gemfile`, YAML manifests | `# Checked <today>: published <date>, active maintenance, no unusual activity` |
| `go.mod`, `build.gradle`, `build.gradle.kts` | `// Checked <today>: …` |
| `pom.xml` | `<!-- Checked <today>: … -->` |

A manifest that cannot hold comments (`package.json`, `composer.json`, other
plain JSON) gets the record wherever AGENTS.md *Security → Dependency policy*
says. If it says nothing, ask the developer once where such records live (a
`docs/dev/dependencies.md` table is a common choice), use the answer, and tell
them to record that place in the dependency policy. Mention the check in the
commit body's `Work done:` as well.
