# JVM (Maven, Gradle)

## Scratch paths

Never staged: `target/`, `build/`, `.gradle/`, `out/`.

## Quality gates

- Format fix: the formatter's write task, usually `mvn spotless:apply` or `./gradlew spotlessApply` (the checking forms are `spotless:check` / `spotlessCheck`).
- Suppression forms, never added on your own initiative: `@SuppressWarnings`, `// NOSONAR`, `// CHECKSTYLE:OFF`, an exclusion in the linter's config.

## Dependency registry

| Manifest | Publish date of `<x.y.z>` | Source repository |
|---|---|---|
| `pom.xml`, `build.gradle*` | `curl -sI https://repo1.maven.org/maven2/<group/as/path>/<artifact>/<x.y.z>/<artifact>-<x.y.z>.pom \| grep -i '^last-modified'` | the same `.pom` without `-I`: the `<scm><url>` element (fall back to `<url>`) |

Maven group IDs become paths by replacing `.` with `/` (`org.example.auth` → `org/example/auth`).

Record: `<!-- Checked <today>: … -->` above the `<dependency>` in `pom.xml`; `// Checked <today>: …` above the line in `build.gradle` / `build.gradle.kts`.
