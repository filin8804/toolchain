# Overview

This directory is where we will store downloaded prebuilt toolchains used to
compile software on very old Linux distros; currently, it is just a mirror of
the _native_ (not _cross_!) musl-based gcc/g++ toolchains available on:

https://musl.cc/

for the architectures I care about, i.e.

`linux-x86_64`

In order to actually run the executables built using the prebuilt toolchain,
we either need to ensure that they are:

1) static:
2) or, if they are dynamic, use the included dynamic linker

Thus, for our purposes, there are four kinds of search paths we will need
to control in order to build and run executables using our custom toolchain:

1) the include path from the C preprocessor
2) the static linker (ld, gold, bfd, etc...) library search path
3) the dynamic linker library search path
4) the compiler driver tool search path, i.e. where it looks for the
   preprocessor, linker, assembler binaries...

In all cases, these paths should live under our toolchain root, for the simple
reason that we do not want to use any of the tools/libraries exported by our
original system because they are too old.

# Setup

In theory, it should be enough to just download the toolchain and run it to
build anything. For some reason, the `syslimits.h` file wasn't found.
This may be related to an issue related to GCC cross compilation builds.
I found an old mailing list post here:

`https://gcc.gnu.org/ml/gcc/2002-08/msg00063.html`

To solve this problem, I copied the `syslimits.h` file from my host system
into the toolchain local folder:

`/usr/${target}/include`

which doesn't exist by default and under which I ignore all files.

## Executable Dynamic Loader Path

Though our toolchain has no problems building executables, we may have
problems running the executables. This is because dynamically linked
executables will use the host system loader by default, which will
try to link it with system installed shared objects instead of our
toolchain locally installed objects. Thus, we use the compiler argument:

`-Wl,--dynamic-linker=${toolchain-linker}`

to instruct the executable to load our toolchain linker.

## Dynamic Loader Setup

Additionally, the dynamic loader installed as part of the toolchain must
be instructed to load libraries we that we compiled and installed via
this toolchain, _not_ standard host libraries. Since our toolchain is
based on musl, we use the config file in our toolchain:

`/etc/ld-musl-${target}.path`

and populate it with directories local to our toolchain installation
folder. To do this, you can run the setup script in the `/meta` folder.

## Moving the Toolchain Folder

If we want to move the toolchain folder, we need to:

1. Update the dynamic linker reference all dynamically linked executables.
2. Update the configuration file for our dynamic linker.

Task (1) can be accomplished with a tool like `patchelf`. Task (2) can
be accomplished with a by editing the configuration file directly or
by using the provided script in the `/meta` folder.

# Usage

All installed objects should be put underneath the toolchain local folder:

`/usr/local`

which doesn't exist by default and under which I ignore all files. The reason
why it is preferable is because the toolchain by default will use libraries
and folders underneath `/usr/local`.

# Reference

Here we list some more details for the curious.

## Compiler Option Reference

Here are some interesting compiler options:

`--sysroot`

Specifies root for library/include path searches

`-I`

Add a directory to the beginning of the include search path

`-Wl,--dynamic-linker`

Set the dynamic linker location for an executable---can be relative---
but that is inherntly insecure.

`-Wl,--rpath`

Sets the embedded `rpath` that we will be used to look up libraries
when the dynamic linker is invoked

`-Wl,--enable-new-dtags`

Sets the embedded `runpath` attribute that will be used to look up
libraries (but overrideable by the `LD_LIBRARY_PATH` variable)

## C Preprocessor Search Path

The default include path for GCC C preprocesser on Linux is:

1. `/usr/local/include`
2. `${libdir}/gcc/${target}/${version}/include`
3. `${libdir}/gcc/${target}/${version}/include-fixed`
4. `/usr/${target}/include`
5. `/usr/include`

All of the above directories may not exist. The list is searched from top to
boottom. Note that the same file may appear twice in the list---this is not a
bug---the GCC non-standard `#include-next` directive forces the preprocessor
to search the list starting from after the item where the current item was
found.

As far as I can tell, on a native compiler installation, the path

`/usr/${target}/include`

is NOT used. Instead, this is used to refer to system specific bits that are
needed when cross-compiling.

## Static Linker Search Path

See below. Essentially, the compiler frontend will usually add paths to the
default path that linker would search if invoked by itself.

## Compiler Driver Search Paths

Here are some flags that the GCC and Clang family of compiler frontends
support to get some of the information above. The most useful option is
probably `-print-search-dirs` because it shows you where the compiler
looks for things when it builds executables.

`-print-file-name=library`

Print the full absolute name of the library file library that would be used when linking—and don’t do anything else.
With this option, GCC does not compile or link anything; it just prints the file name.

`-print-multi-directory`

Print the directory name corresponding to the multilib selected by any other switches present in the command line.
This directory is supposed to exist in `GCC_EXEC_PREFIX`.

`-print-multi-lib`

Print the mapping from multilib directory names to compiler switches that enable them.
The directory name is separated from the switches by ‘;’, and each switch starts with an ‘@’
instead of the ‘-’, without spaces between multiple switches. This is supposed to ease shell processing.

`-print-multi-os-directory`

Print the path to OS libraries for the selected multilib, relative to some lib subdirectory.
If OS libraries are present in the lib subdirectory and no multilibs are used, this is usually just ..
If OS libraries are present in libsuffix sibling directories this prints e.g. ../lib64, ../lib or ../lib32,
or if OS libraries are present in lib/subdir subdirectories it prints e.g. amd64, sparcv9 or ev6.

`-print-multiarch`

Print the path to OS libraries for the selected multiarch, relative to some lib subdirectory.
`-print-prog-name=program` Like `-print-file-name`, but searches for a program such as cpp.
`-print-libgcc-file-name`  Same as `-print-file-name=libgcc.a`; e.g. you can  `gcc -nostdlib files… $(gcc -print-libgcc-file-name)`

`-print-search-dirs`

Print the name of the configured installation directory and a list of program and library directories gcc searches.

`-print-sysroot-headers-suffix`

Print the suffix added to the target sysroot when searching for headers

`-print-sysroot`

Print target sysroot directory is used during compilation. This is specified either at configure time or using --sysroot option,
possibly with an extra suffix that depends on compilation options. If no target sysroot is specified, the option prints nothing.

`-dumpmachine`

Print the compiler’s target machine (for example, ‘i686-pc-linux-gnu’)—and don’t do anything else.

`-dumpversion`

Print the compiler version and don’t do anything else. This is the compiler version used in filesystem paths and specs.

`-dumpspecs`

Print the compiler’s built-in specs—and don’t do anything else. (This is used when GCC itself is being built.) See Spec Files.

## Dynamic Linker Search Paths

On Linux, the dynamic linker usually lives under `/lib/ld-${vendor}-linux.so` (possibly with a number attached).
Often, the dynamic linker is built as special _executable_ library---which means it can be run as a binary or
linked into an exectuable. Since the dynamic linker has to work with shared objects built by the compiler,
their relationship is very close---the compiler and linker cannot be arbitrarily swapped. Sometimes, the
linker may depened on the Linux version used as well.

The set of paths searched by the dynmaic linker is actually quite complicated. The path can either be:

1. complied into the executable we want to dynamically link (via `-rpath` or `-runtimepath` linker options)
2. compiled into the dynamic linker binary itself
3. set by a configuration file which the dynamic linker reads (usually under `/etc`)
4. set by an environment variable which the dynamic linker reads (`LD_LIBRARY_PATH`)

Different dynamic linkers have different policies about this.

### GCC Dynamic Linker

To query the GCC DEFAULT dynamic linker search directory order, we want this cantation:

`ldconfig -v 2>/dev/null | grep -v ^$'\t'`

`ldconfig` is a binary that queries a cache file which stores paths to search.

However, this doesn't work when the default search path is modified by environment variables
or by values embedded in an exectuable. To see those search paths, we have two options:

1) use the `ldd` tool (which has knonwn insecurities)
2) use the `LD_DEBUG` environment variable when running an executable

### Musl Dynamic Linker

The default search order for the musl dynamic linker is usually:

1. `/lib`
2. `/usr/local/lib`
3. `/usr/lib`

But it can be configured by the configuration file `/etc/ld-musl-${target}.path`
which is just a colon delimited list of directories. Unlike the GCC linker,
the musl linker does not support the `LD_DEBUG` environment variable---
however, it's `ldd` does respect the `LD_LIBRARY_PATH` environment variable
so that you can configure and then check.

### Patchelf

The tool `patchelf` can inspect and change the rpath and runpath attributes
inside of an ELF binary. This combined with the above tools can provide a
standard way to examine dynamic linker behavior for different linkers.
