[![License](https://img.shields.io/badge/License-Apache-blue.svg)](LICENSE)

**This project is in the Alpha stage. All API's might change without warning and no guarantees are given about stability. Do not use it in production.**

# Description
Custom generator for RealmObjects, which uses named parameters for required fields
Also generates builders for each RealmObject

# Usage

* Add a dependency to [realm](https://pub.dev/packages/realm) package or [realm_dart](https://pub.dev/packages/realm_dart) package to your application.
* Add a development dependency on this repo (TODO Published package?)
* Add the following block to `build.yaml` to disable the default realm generator:
```yaml
targets:
  $default:
    builders:
      realm:realm_generator: # or `realm_dart:realm_generator` for dart projects
        enabled: false
```

To generate RealmObjects

* Run `dart run build_runner build --delete-conflicting-outputs` to generate once
* Run `dart run build_runner watch --delete-conflicting-outputs` to generate on file change

##### The "Dart" name and logo and the "Flutter" name and logo are trademarks owned by Google.