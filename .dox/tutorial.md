# fpm-modules


## Introduction

Not so long ago, I came across a [thread](https://fortran-lang.discourse.group/t/running-on-computer-without-fpm-and-other-questions/9097/4?u=davidpfister) describing potential use of [fpm](https://fpm.fortran-lang.org/) to create plugins and other related tools for Fortran projects. One of the comments particularly triggered my curiosity:

> A dump of the model in a standard format was a missing component for more powerful plugins in general. Was just looking at how complete `fpm build --dump $FILENAME` is, as if everything is there it seems like a natural to make a “fpm-generate” plugin that at least makes a gmake(1) input file.

That did look very interesting and When I read this I really wanted to try to make use of it. The dump file is either json or toml (based on the extension) and can be serialized by another project to make use of it. That being said, the serialization still requires to parse the output file (using [json-fortran](https://github.com/jacobwilliams/json-fortran) or [TOML.fortran](https://toml-f.readthedocs.io/en/latest/) for instance), and make use of the model to build static analyzer, output build sequence, generate make file, etc.

The dump (or at least the beginning of it) looks like this:
```json
{
    "package-name": "fpm-modules",
    "compiler": {
        "id": 1,
        "fc": "gfortran",
        "cc": "gcc",
        "cxx": "g++",
        "echo": false,
        "verbose": false
    },
    "archiver": {
        "ar": "ar -rs ",
        "use-response-file": true,
        "echo": false,
        "verbose": false
    },
    "fortran-flags": "-cpp -Wall -Wextra -fPIC -fmax-errors=1 -g -fcheck=bounds -fcheck=array-temps -fbacktrace -fcoarray=single",
    "c-flags": "",
    "cxx-flags": "",
    "link-flags": "",
    "build-prefix": "build\\gfortran",
    "include-dirs": [
        ".\\.\\include",
        "build\\dependencies\\fortran-regex\\src"
    ],
    "link-libraries": [],
    "external-modules": "ifcore",
    "include-tests": false,
    "module-naming": false,
    "deps": {
        "unit": 6,
        "verbosity": 1,
        "dep-dir": "build\\dependencies",
        "cache": "build\\cache.toml",
        "ndep": 9,
        "dependencies": {
            "fpm-modules": {
                "name": "fpm-modules",
                "path": ".",
                "version": "0.1.0",
                "proj-dir": ".\\.",
                "done": true,
                "update": false,
                "cached": false
            },
            "fpm": {
                "name": "fpm",
                "git": {
                    "descriptor": "default",
                    "url": "https://github.com/fortran-lang/fpm"
                },
                "version": "0.11.0",
                "proj-dir": "build\\dependencies\\fpm",
                "revision": "3f0a304cd195caace551138bb0e0c77e4579b60d",
                "done": true,
                "update": false,
                "cached": true
            },
            "json-fortran": {
                "name": "json-fortran",
                "git": {
                    "descriptor": "default",
                    "url": "https://github.com/jacobwilliams/json-fortran"
                },
                "version": "0",
                "proj-dir": "build\\dependencies\\json-fortran",
                "revision": "2dc8abefd416ec791b100a37d92d5be9f8fa46e8",
                "done": true,
                "update": false,
                "cached": true
            },
...
```
The json schema is relatively easy to understand and rather straightforward. That being said, making use of it still requires quite some time and efforts. 

It's not until the publication of the [fpm-deps](https://github.com/ivan-pi/fpm-deps) that I realized that I could also make [fpm](https://fpm.fortran-lang.org/) a dependency and interact with the model programmatically. That repo gave me just enough material to get me started. And since the whole process took me a bit of research and trial and error, I thought I could make a tutorial out of it for anyone willing to try. 

## Scope

In the following, we will use `fpm` to create a dependency chart of all the modules used by a project. 

The code described in this tutorial is available on [GitHub](https://github.com/davidpfister/fpm-modules). 
If you want to do it on your own, you will need: 
- a fortran compiler
- fpm, the fortran package manager

## The fpm project

The Fortran Package Manager ([fpm](https://fpm.fortran-lang.org/)) is a community-driven, open-source tool designed to streamline the development, building, and management of Fortran projects. Modeled after Rust's Cargo, fpm simplifies the process of creating Fortran applications and libraries by providing an intuitive command-line interface for tasks such as project initialization, compilation, testing, and dependency management. Its key goal is to enhance the user experience for Fortran programmers by automating build processes, managing dependencies, and fostering a growing ecosystem of modern Fortran libraries and applications. Fpm supports features like parallel builds with OpenMP, integration with version control systems like Git, and a plugin system that allows developers to extend its functionality. Whether you're building a simple program or a complex library with multiple dependencies, fpm provides a robust framework to make Fortran development more efficient and accessible.

## Getting started 

Create a new project using `fpm` and the `new` command.
```bash
fpm new "fpm-modules"
```

`fpm` generates a sample toml file that needs to be edited. In order, to use `fpm` itself as a dependency, it needs to be added into the dependency list. 

```toml
name = "fpm-modules"
version = "0.1.0"
license = "license"
author = "davidpfister"
maintainer = "davidpfister"
copyright = "Copyright 2025, davidpfister"
description = "Generate dependency graphs of Fortran modules"

[build]
auto-executables = true
auto-tests = true
auto-examples = true
module-naming = false

[install]
library = false
test = false

[fortran]
implicit-typing = false
implicit-external = false
source-form = "free"

[dependencies]
fpm = {git = "https://github.com/fortran-lang/fpm"}
```

Navigate to the `src` folder and create your main module. I named mine `package.f90`. The following modules from 
## Description of the build model

Since `fpm` is essentially a build system for Fortran project, it can partially parse a Fortran project and create a build tree. The idea is to make use of that build tree to generate a dependency chart. 

Looking at the source code it appears that one needs to instantiate a [package_config_t](https://fortran-lang.github.io/fpm/type/package_config_t.html) and access the nested components `modules_provided` and `module_used`. 

Here are reported the components that will mater be used in this tutorial.

```
-    package_config_t
                    |- model
                           |- external_modules
                           |- packages(:)
                                       |-   name
                                       |- sources(:)
                                                  |- modules_provided(:)
                                                  |- module_used(:)
``` 

## Building the model

Building the build model is rather easy and requires a call to the `build_model(...)` subroutine. There is a catch though: the subroutine takes a `fpm_build_settings` object as argument which is normally created from environmental variables and command lines. 

As far as I can tell, there is no default build settings that can be easily used so one has to create one from scratch. Since we are not really compiling the project but stopping after the generation of the build tree, most of the values used in the settings object are of no importance. 

The following default settings are used in the following:
```
settings = fpm_build_settings(  &
        & profile=" ",&
        & dump='fpm_model.toml',&
        & prune= .false., &
        & compiler=get_fpm_env("FC", "gfortran"), &
        & c_compiler=get_fpm_env("CC", " "), &
        & cxx_compiler= get_fpm_env("CXX", " "), &
        & archiver= get_fpm_env("AR", " "), &
        & path_to_config= " ", &
        & flag=" ", &
        & cflag=" ", &
        & cxxflag=" ", &
        & ldflag=" ", &
        & list=.false.,&
        & show_model=.false.,&
        & build_tests=.false.,&
        & verbose=.false.)
```

I usually find it more convenient to extend derived types from third party libraries and add the components and type-bound procedures as needed. In the present case, I created a `package` type, that extends the `package_config_t` object from the `fpm` project. 
I extended the type with a `create` subroutine that will take case of instantiating the build model based on the previous settings.

```fortran
    type, extends(package_config_t), public :: package
        private
        type(fpm_model_t), public :: model
    contains
        procedure, pass(this), public :: create => package_create
    end type

    contains 

    subroutine package_create(this)
        class(package), intent(inout)   :: this
        !private
        type(fpm_build_settings) :: settings
        type(error_t), allocatable :: error

        settings = fpm_build_settings(  &
        & profile=" ",&
        & dump='fpm_model.toml',&
        & prune= .false., &
        & compiler=get_fpm_env("FC", "gfortran"), &
        & c_compiler=get_fpm_env("CC", " "), &
        & cxx_compiler= get_fpm_env("CXX", " "), &
        & archiver= get_fpm_env("AR", " "), &
        & path_to_config= " ", &
        & flag=" ", &
        & cflag=" ", &
        & cxxflag=" ", &
        & ldflag=" ", &
        & list=.false.,&
        & show_model=.false.,&
        & build_tests=.false.,&
        & verbose=.false.)

        call build_model(this%model, settings, this%package_config_t, error)
        if (allocated(error)) then
            call fpm_stop(1,'*package_build* Model error: '//error%message)
        end if
    end subroutine
```