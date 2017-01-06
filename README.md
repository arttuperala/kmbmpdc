![kmbmpdc](http://perala.me/kmbmpdc/header.png)

kmbmpdc is a macOS menubar application for controlling [music player daemon](https://www.musicpd.org/) playback.

## Features

- [x] Menubar buttons for play/pause and track skip
- [x] Submenu for additional controls
- [x] Media key support
- [x] Track change notifications with cover art

## System requirements

kmbmpdc requires 10.11 or newer.

## Download

Official builds can be found in Github releases. The releases are unsigned.

## Usage

If you are running mpd on the local machine with the default port, kmbmpdc should connect automatically to the server on initial start. If this is not the case, you can edit the host and port in the application preferences.

Controlling mpd is done via the menubar. Play/pause and track skip can be found directly on the menubar. Further options can be opened with the right-most menu button. It also contains preferences, connect/disconnect and exit. Play/pause, next track and previous track are also available via the Mac media keys.

Track change notifications are enabled by default. They can be disabled in the preferences. To enable cover art, specify the media library root that is being used by mpd, as the cover art is obtained from the media files themselves.

### Cover art in notifications

Cover art in notifications currently supports ID3v2 embedded art (ID3v2.3 and ID3v2.4 only) or artwork stored in the same directory as the track in question. In order for the feature to work, media library path must be set in kmbmpdc preferences.

The following priority is used for cover art images:

1. *cover.jpg* in music file directory
2. *cover.png* in music file directory
3. ID3v2 embedded cover art

## Development

### Building

#### Dependencies

* [libmpdclient](https://www.musicpd.org/libs/libmpdclient/)
* [Maku](https://github.com/arttuperala/Maku)
* [MediaKeyTap](https://github.com/nhurden/MediaKeyTap)

#### Requirements

The following tools/packages are required for building kmbmpdc and its dependencies.

* [automake](https://www.gnu.org/software/automake/)
* [autoconf](https://www.gnu.org/software/autoconf/autoconf.html)
* [libtool](https://www.gnu.org/software/libtool/)
* [Carthage](https://github.com/Carthage/Carthage)
* [Xcode](https://developer.apple.com/xcode/)

#### Build instructions

1. Clone the repository with submodules

        git clone --recursive https://github.com/arttuperala/kmbmpdc.git

2. Download and build Carthage dependencies

        carthage bootstrap

3. Build libmpdclient

        cd libmpdclient
        ./autogen.sh --disable-documentation
        make
        cd ..

    **Note:** if you are using libtool installed with Homebrew, you'll want to change `libtoolize` commands in *autogen.sh* to `glibtoolize`, since the Homebrew version prepends *"g"* in front of the tools to prevent conflicts with system tools.

4. Build kmbmpdc

        xcodebuild -target kmbmpdc -configuration Release

### Code style

[SwiftLint](https://github.com/realm/SwiftLint) is used to enforce code style and conventions.

## License

kmbmpdc is licensed under Apache License 2.0. See `LICENSE` for more details.

libmpdclient is licensed under the revised BSD License. See `libmpdclient/COPYING` for more details.

