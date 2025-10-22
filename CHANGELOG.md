# TestCoverage

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.8] - Unreleased

### Fixed
- #70: Performance regression on newer IRIS versions when table stats are missing on a clean instance/run

## [4.0.7] - 2025-09-23

### Fixed
- #66: No longer errors when a `[ Language = python ]` method has a name starting with "%"
- coverage.list files with Windows-style line endings are now parsed properly in containers

## [4.0.6] - 2025-08-13

### Fixed
- #63: TestCoverage.Manager On/After methods now call superclass so improvements to %UnitTest.Manager like AutoUserNames will work properly

## [4.0.5] - 2024-11-04

### Fixed
- #57: Improve SQL performance when mapping run coverage

## [4.0.4] - 2024-10-15

### Fixed
- #54: Defend against possible configuration-dependent SQL exceptions in mapping INT to MAC/CLS coverage

## [4.0.3] - 2024-08-19

### Fixed
- #52: Method mapping code now doesn't use AST's endline_no property to support older python versions
- #53: Ignore traced commands from code without a class name

## [4.0.2] - 2024-08-16

### Fixed
- #51: Don't start (and stop) the ObjectScript and Python monitors if there are no ObjectScript/Python routines being tracked respectively, fixes error from trying to start/stop the %Monitor.System.LineByLine with no routines


## [4.0.1] - 2024-08-16

### Fixed
- #45: Fixed Python line 0 tracking for 2024.2
- #46: Fix for bug caused by UpdateComplexity calling GetCurrentByName unnecessarily and causing dependency issues
- #47: Fixed mapping issue caused by empty lines at top of Python method not showing up in compiled Python
- #48: When the Line-By-Line Monitor resumes after pausing, resume the Python tracer too
- #49: Added user parameter for preloading python modules (fixes problem of pandas breaking sys.settrace on first import)

## [4.0.0] - 2024-08-01

### Changed
- #29: As a consequence of this change, the minimum supported platform version is 2022.1

### Added
- #29: Track code coverage for embedded python methods in .cls files
- #42: Added a listener interface and manager with an associated user parameter, allowing the user to broadcast output on test method/case/suite completion.

## [3.1.1] - 2024-07-31

### Fixed
- #39: Fixed bug where results viewer gave divide by zero error when there were 0 executed methods in the covered code
- #41: Now the code strips leading and trailing whitespace from coverage.list, so "PackageName.PKG " will still be loaded properly

## [3.1.0] - 2024-07-05

### Added
- #23: Allow CoverageClasses and CoverageRoutines to be specified as %DynamicArray in addition to $ListBuild() lists.
- #14: Added a straightforward way to find and track coverage on all interoperability processes in the current namespace

### Fixed
- #24: Whenever a new tag is created, a new release will be published using the tag string as its version. The release also comes with an export of the TestCoverage package in XML.

## [3.0.0] - 2023-12-01

### Changed
- #25: As a consequence of this change, the minimum supported platform version is 2019.1.

### Fixed
- #18: EOL normalization in coverage.list
- #19: Update CI to latest IRIS community (and corresponding test updates)
- #25: Fix so the tool works on 2023.1

## [2.1.3] - 2022-03-30
- Last released version before CHANGELOG existed.
