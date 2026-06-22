# Changelog

All notable changes to Flightdeck. The format follows
[Keep a Changelog](https://keepachangelog.com/), and versions are
[semantic](https://semver.org/) git tags (`vX.Y.Z`). Each tagged release also
has a [GitHub Release](https://github.com/dcltdw/Flightdeck/releases) with the
built `.iq` attached for quick rollback — see [docs/releasing.md](docs/releasing.md).

There is no version field in the Connect IQ manifest; the git tag is the version.

## [Unreleased]

- Initial public, trademark-clean variant: four themes (Cockpit / Bridge /
  Bulkhead / Phosphor) × dark/light, selectable via app settings; live metrics
  from `Activity.Info` (session pace/distance, elapsed hero, lap pace/time);
  custom bitmap fonts; procedural radar watermark for Phosphor.
- Responsive multi-device support: renders across AMOLED running watches at
  390×390, 360×360, 416×416, and 454×454 (Forerunner 70/165/170/265/265s/965/970,
  Fenix 8, Epix 2, Venu 3/3s). Layout and bitmap fonts scale from a 390 reference;
  each device bundles only its resolution's assets.
