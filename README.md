# Bis (Build Install Script)

Bis is a wrapper for bash meant to help automate compilation and installation of  software in a consistent way while remaining flexible and simple.  Hopefully it can replace rpmbuild by emulating some of its more useful features without its more distribution oriented features.

The basic usage of bis is `bis build-script.bis` where `build-script.bis` is a filename in the form of alternating (name, version) pairs delimited with dashes.  Bis will:

- Exports several build-related bash functions, documented below.
- Splits the filename into tokens on hyphens (`-`)
- Sets $NAME to the first token and $VERSION to the second token.  NAME{2,3} and VERSION{2,3} are set for additional tokens.
- Invokes the script as a bash function with all of tokens passed as arguments (`$@`) so that the NAME amd VERSION variables can be fixed manually if necessary.

Bis expects $INSTALL_ROOT and $SOURCES to be defined prior to script invocation.  This means the tool invoking the script (eg Jenkins) can set INSTALL_ROOT based on whether it is a production build or not.

A simple bis script might look like this:

Filename: `hello-0.0.1-generic.bis`
```
SUMMARY="Hello, World"

#Set important variables based on environment and filename (including $INSTALL_DIR)
# also creates and cds to $WORKSPACE at /n/app/bis/workspace/hello-0.0.1-generic
bis-init

# Clean and unpack source into workspace
# Determins $UNPACKPATH and cds to it
# /n/app/bis/workspace/hello-0.0.1-generic/hello-0.0.1
bis-unpack

./configure --prefix=$INSTALL_DIR
make
make install

# Write a bis-install.txt and append to bis-install.log
bis-finish
```

### Variables

#### Variables set to a default value, intended to be overridden by calling environment

- `INSTALL_ROOT` - Root directory for all installations. Should be set in environment. (`/n/app`)
- `SOURCES` - Path to source repository.  Should be set in environment. (`/n/app/sources`)
- `WORKSPACE_ROOT` - Path to build workspace directory.  Source tarballs will be unpacked to this directory. (`/n/app/bis/workspace`)

#### Set by `bis` before script is called.
- `FULLNAME` - Full name of the file, without the `.bis` extension. Set by `bis` before invoking the script.  (`python-2.7.14-gcc-6.2.0`)
- `WORKSPACE` - Set by `bis` to `$WORKSPACE_ROOT/$FULLNAME` `/n/app/bis/workspace/python-2.7.14-gcc-6.2.0`
- `NAME` - Name of the application.  Set by `bis` to the first token in filename. (`python`)
- `VERSION` - Version of the application, the second token in the filename (`2.7.14`)
- `NAME2` - Name of compiler, etc.  Third filename token (`gcc`)
- `VERSION2` - Version of compiler, etc. Fourth filename token. (`6.2.0`)

#### Set by `bis-init`.
- `SOURCE_FILENAME` - The base filename of the source tarball. Set by `bis-init` to $NAME-$VERSION.$extension, where extension is determined by searching $SOURCES for supported archive formats.  (`python-2.7.14.tgz`)
- `SOURCE` - The full path to the source tarball.  Set to `$SOURCES/$SOURCE_FILENAME`.  (`/n/app/sources/python-2.7.14.tgz`)
- `INSTALL_DIR` - Install prefix for the application.  Set by `bis-init` to `$INSTALL_ROOT/$NAME/$VERSION` (`/n/app/python/2.7.14`)
- `UNPACKPATH` - Inspects the $SOURCE archive to see if it extracts to a single directory.  If the archive has multiple directories or files in its root, `UNPACKPATH` is set to `WORKSPACE`.  (`/n/app/bis/workspace/python-2.7.14-gcc-6.2.0/Python-2.7.14`)

#### Not set by anything, but may be used.

- `BUIlD_OWNER` - used by `bis-finish` when writing `bis-install.log`
- `DESCRIPTION` - used by `bis-finish` when writing `bis-install.txt`
- `SUMMARY` - used by `bis-finish` when writing `bis-install.txt`

### Functions

#### bis-description

```
bis-description <<<EOF
Description of the application
goes here.
EOF
```

Wrapper function to set `$DESCRIPTION` using HEREDOC syntax without messy with `cat` or pipes.  Still kind of ugly, but it's just metadata.

#### bis-init

`bis-init [no-cd-to-workspace]`

Call this first, unless you need to override any of the values it sets.  After setting environment variables, `bis-init` changes the working directory to `$WORKSPACE`, unless `no-cd-to-workspace` is passed.

#### bis-verify

Checks to see if important variables are defined, and that the source package exists.

#### bis-unpack

`bis-unpack`

Removes $UNPACKPATH if it exists, then decompresses and untars $SOURCE to $WORKSPACE.

When finished, changes working directory to $UNPACKPATH.

#### bis-clean

`bis-clean [just-make-clean]`

Does `rm -rf $UNPACKPATH`, unless `just-make-clean` is passed, in which case it cds to $UNPACKPATH and runs `make clean`.

#### bis-show-vars

`bis-show-vars`

Echo all variables with values to standard output.

#### bis-finish

`bis-finish`

Writes an info file and logfile to the $INSTALL_DIR.

#### bis-determine-unpackdir

`bis-determine-unpackdir <archive-file>`

Attempts to determine the directory the given archive file extracts to. If multiple files or directories are found in the root of the archive, this retuns nothing.

#### bis-set-unpack-path

`bis-set-unpack-path`

Sets $UNPACKPATH to `$WORKSPACE/$(bis-determine-unpackdir $SOURCE)`.
