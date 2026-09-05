fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android test

```sh
[bundle exec] fastlane android test
```

Static analysis and unit/widget tests (flutter analyze + flutter test)

### android bump

```sh
[bundle exec] fastlane android bump
```

Set the version in pubspec.yaml. Options: version_name:1.2.0 build_number:12 (build_number defaults to Play's highest + 1)

### android build

```sh
[bundle exec] fastlane android build
```

Build a release App Bundle (obfuscated, with split debug info). Option: build_number:N

### android apk

```sh
[bundle exec] fastlane android apk
```

Build a release APK (used by the security lane; obfuscated). Option: allow_debug_signing:true

### android internal

```sh
[bundle exec] fastlane android internal
```

Release to Internal testing. Options: changelog:'...' version_name:x.y.z build_number:N skip_tests:true skip_bump:true status:draft

### android alpha

```sh
[bundle exec] fastlane android alpha
```

Release to Closed testing (alpha track). Same options as internal

### android beta

```sh
[bundle exec] fastlane android beta
```

Release to Open testing (beta track). Same options as internal

### android production

```sh
[bundle exec] fastlane android production
```

Release to Production with a staged rollout. Options: rollout:0.1 (default PLAY_DEFAULT_ROLLOUT) plus the internal lane options

### android promote

```sh
[bundle exec] fastlane android promote
```

Promote an existing release between tracks without rebuilding. Options: from:internal to:production rollout:0.1 version_code:N

### android rollout

```sh
[bundle exec] fastlane android rollout
```

Increase the staged rollout of the current production release. Option: rollout:0.5 (1.0 = complete)

### android metadata

```sh
[bundle exec] fastlane android metadata
```

Upload the store listing (title, descriptions, icon, feature graphic, screenshots) from fastlane/metadata

### android download_metadata

```sh
[bundle exec] fastlane android download_metadata
```

Pull the current store listing from Play into fastlane/metadata (overwrites local files)

### android validate_key

```sh
[bundle exec] fastlane android validate_key
```

Check the Play service-account key works

### android security

```sh
[bundle exec] fastlane android security
```

Security test-suite: secrets scan, dependency CVEs, static analysis, release-APK manifest/signing audit, MobSF. Options: mobsf:false skip_build:true allow_debug_signing:true

### android preflight

```sh
[bundle exec] fastlane android preflight
```

Everything a release needs, without uploading: test + security + build

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
