Autobuild4
==========

Autobuild4 is an semi-automated packaging toolkit for AOSC OS.

Based on source and package definitions, Autobuild4 can:

- Prepare and patch source code for building.
- Build source code based on pre-defined or custom build templates and scripts.
- Perform quality assurance checks on scripts and built binaries.
- Perform testing routines on built binaries.
- Package built binaries in the dpkg format (`.deb`).
- Manage and invoke package builds from a tree.

Autobuild4 is a successor to the [Autobuild3](https://github.com/AOSC-Dev/autobuild3) used between 2015 and 2023.

Installing Autobuild4
---------------------

### Dependencies

- CMake >= 3.12
- GCC >= 4.9 (Boost >= 1.72 is required if GCC < 9, Fmt >= 8 is required if GCC < 13)
- nholmann-json >= 3.8
- Glibc and Bash headers

### Building and Installing

```
cmake .
make
make install
```

Documentation
-------------

- [User Manual](https://wiki.aosc.io/developer/packaging/autobuild4/).
- [API Reference](https://wiki.aosc.io/developer/packaging/autobuild4/api/).
