# frc-maven

A static Maven repository for a set of FRC robot libraries, served by GitHub Pages at:

```
https://mikegrundvig.github.io/frc-maven/
```

It is plain files in the standard Maven layout (`com/michaelgrundvig/frc/<artifact>/<version>/`):
jars, sources and Javadoc jars, POMs, Gradle module metadata, and their checksums. Nothing is built
here; each library's own build publishes into a clone of this repository, and a commit and push
puts the release online. `.nojekyll` has Pages serve every file as it is.

## The libraries

Every library of a release has the same version, the date of the release (`2026.10.24`). They are
pre-release: anything may change from one version to the next, with no promise of compatibility.

| Artifact (`com.michaelgrundvig.frc:`) | What | Source |
|---|---|---|
| `frc-robot-runtime` | The robot program every robot shares: the loop, the drivetrain, the mechanisms built from a robot's definition, vision and localization's wiring, autos, the simulator's adapters, and (test fixtures) the harness a team tests its robot with | [frc-robot-runtime](https://github.com/mikegrundvig/frc-robot-runtime) |
| `frc-robot-simulation` | The simulated world's physics and sensors, and the catalog of what can go wrong | [frc-robot-runtime](https://github.com/mikegrundvig/frc-robot-runtime), `lib/simulation` |
| `frc-gradle-plugins` | The runtime's Gradle plugins: `frc.advantagescope-assets` | [frc-robot-runtime](https://github.com/mikegrundvig/frc-robot-runtime), `build-logic` |
| `frc-robot-model` | What an FRC field and robot are, as data: the validation kit, the field, the robot's definition | [frc-robot-model](https://github.com/mikegrundvig/frc-robot-model) |
| `frc-docs-processor` | The annotation processor that writes configuration records' Javadoc into the jar | [frc-robot-model](https://github.com/mikegrundvig/frc-robot-model), `docs-processor` |
| `frc-localization` | Where the robot is, from its wheels, IMUs and cameras; (test fixtures) the localizer conformance suite | [frc-localization](https://github.com/mikegrundvig/frc-localization) |
| `frc-pitwall` | The robot program's own web page and API | [frc-pitwall](https://github.com/mikegrundvig/frc-pitwall) |

Each library also publishes a `-test-sources` jar, its tests' sources, which the runtime's guides
check their examples against.

WPILib and the vendor libraries (Phoenix 6, REVLib, AdvantageKit, PhotonLib, Commands v3) are not
here and no library brings them: a robot program has its own, from GradleRIO and its vendordeps,
and the libraries compile against them (`provided` in the POMs). The runtime's jar says which
versions it was built with (`META-INF/frc-robot-runtime/built-with.json`), so a program's build
can check it uses the same.

## Using it

The [robot template](https://github.com/mikegrundvig/frc-robot-template) is set up already. Any
other Gradle build adds the repository, limited to the libraries' group:

```groovy
// build.gradle
repositories {
    exclusiveContent {
        forRepository {
            maven { url = "https://mikegrundvig.github.io/frc-maven/" }
        }
        filter { includeGroup "com.michaelgrundvig.frc" }
    }
}
dependencies {
    implementation "com.michaelgrundvig.frc:frc-robot-runtime:2026.10.24"
    testImplementation testFixtures("com.michaelgrundvig.frc:frc-robot-runtime:2026.10.24")
}
```

The plugin is found through `pluginManagement` in `settings.gradle`, the same repository with the
plugin's marker group too (`includeGroup "frc.advantagescope-assets"`), then
`id "frc.advantagescope-assets" version "2026.10.24"`.

## Making a release

1. Set the release's version, `frc-libs` in `gradle/libs.versions.toml`, to the same date in each
   library: the model, localization, Pitwall and the runtime. Commit it there.
2. With the libraries' clones in one folder (`model/`, `localization/`, `pitwall/`, `runtime/`),
   run from this repository:

   ```bash
   ./release.sh <folder>           # build, check, publish in order, commit here
   ./release.sh --push <folder>    # the same, then git push
   ```

   For each library in order (model, localization, Pitwall, runtime) it runs
   `./gradlew publishToFrcMaven`: every check (`ci`), then the publication into this clone. Each
   library after the model reads the ones before it from this clone (`-PfrcMaven=file://...`), so
   nothing waits on Pages. Then it commits what changed here, as `Release <version>`.
3. After the push, Pages serves the release within a few minutes. Move a robot program to it by
   its `frc-libs` line.

Each library publishes on its own the same way: `./gradlew publishToFrcMaven` in its clone writes
into `../frc-maven`, or the folder `-PfrcMavenDir=<folder>` names. A version once pushed stays as
it is: publish a fix as a new version, since builds check the files' checksums.

## License

[BSD 3-Clause](LICENSE), the same as the libraries it serves.
