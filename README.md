# express-c template

## Installation

The easiest way is to open this in a GitHub Codespace and skip managing your development environment entirely.

### Install local dependencies

#### OS X

```
$ brew install llvm clib fswatch dbmate
$ git clone https://github.com/williamcotton/express-c.git
$ cd express-c
$ make install
```

#### Linux

The primary requirements are `clang`, `libbsd`, `libblocksruntime` and `libdispatch`.

Otherwise see the [Devcontainer Dockerfile](https://github.com/williamcotton/express-c-template/blob/master/.decvcontainer/Dockerfile) for instructions on how to build the dependencies.

## Usage

Start your app in development mode and recompile and restart whenever you make changes.

```
$ make app-watch
```

Run your tests in watch mode and recompile and rerun whenever you make changes.

```
$ make test-watch
```

## Testing

There is a GitHub Action for testing your app on push that does the following, but you can also do it yourself locally:

Run clang-tidy:

```
$ make lint
```

Run clang format:

```
$ make format
```

Run tests with leak detection (`valgrind` on linux, `leaks` on darwin):
```
$ make test-leaks
```

Run the tests:
```
$ make test
```

Gather code coverage data:
```
$ make test-coverage-html
```
