[![kmbmpdc](https://kmbmpdc.perala.me/static/githubheader.png)](https://github.com/arttuperala/kmbmpdc)
[![Travis](https://img.shields.io/travis/arttuperala/kmbmpdc.svg?maxAge=3600)](https://travis-ci.org/arttuperala/kmbmpdc)
[![Meido](https://meido.perala.me/kmbmpdc/badge.svg?maxAge=3600)](https://meido.perala.me/kmbmpdc)
[![GitHub release](https://img.shields.io/github/release/arttuperala/kmbmpdc.svg?maxAge=43200)](https://github.com/arttuperala/kmbmpdc/releases/latest)
[![Github All Releases](https://img.shields.io/github/downloads/arttuperala/kmbmpdc/total.svg?maxAge=28800)](https://github.com/arttuperala/kmbmpdc/releases)
[![Website](https://img.shields.io/website-up-down-green-red/https/kmbmpdc.perala.me.svg?maxAge=3600)](https://kmbmpdc.perala.me)

kmbmpdc is a macOS menubar application for controlling [music player daemon](https://www.musicpd.org/) playback.

## Features

- [x] Menubar icon indicating playback
- [x] Popout window with playback controls and cover art
- [x] Media key support
- [x] Upcoming track queue
- [x] Track search
- [x] Playlist support
- [x] Stop after current track
- [x] Track change notifications with cover art

## System requirements

kmbmpdc requires 10.11 or newer.

## Installation

Official builds can be found in [Github releases](https://github.com/arttuperala/kmbmpdc/releases). The releases are unsigned.

If you are using [Homebrew-Cask](https://github.com/caskroom/homebrew-cask), you can install the official build with the command:

    brew cask install kmbmpdc

## Usage

If you are running MPD on the local machine with the default port and without a password, kmbmpdc should connect automatically to the server on initial start. If this is not the case, you can edit the host, port and password in the application preferences.

Controlling MPD is done via the media keys or by opening the controller from the menubar icon. Media keys support play/pause, next track and previous track. The menubar controller supports the same functions as the media keys plus stop, stop after current track, playlists and different MPD modes.

Track search is opened by clicking on the magnifying glass icon in the controller. The search is performed when the input field on the top of the UI is given a string and Enter is pressed. Individual tracks can be appended at the end of the queue by double-clicking on them. Multiple selections can be added to the beginning or end of the queue by right-clicking the selection and choosing the appropriate action.

Track change notifications are enabled by default. They can be disabled in the preferences. To enable cover art, specify the media library root that is being used by mpd, as the cover art is obtained from the media files themselves.

If you are connecting to a password-protected server, make sure that the client has `read` and `control` permissions.

### Cover art in notifications

Cover art in notifications currently supports ID3v2 embedded art (ID3v2.3 and ID3v2.4 only) or artwork stored in the same directory as the track in question. In order for the feature to work, media library path must be set in kmbmpdc preferences.

The following priority is used for cover art images:

1. *cover.jpg* in music file directory
2. *cover.png* in music file directory
3. ID3v2 embedded cover art

## Development

### Building

#### Dependencies

* [imeji](https://github.com/arttuperala/imeji)
* [libmpdclient](https://www.musicpd.org/libs/libmpdclient/)
* forked [MediaKeyTap](https://github.com/arttuperala/MediaKeyTap)

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

        cd Frameworks/libmpdclient
        ./autogen.sh --disable-documentation
        make
        cd ../..

    **Note:** if you are using libtool installed with Homebrew, you'll want to change `libtoolize` commands in *autogen.sh* to `glibtoolize`, since the Homebrew version prepends *"g"* in front of the tools to prevent conflicts with system tools.

4. Build imeji

        cd Frameworks/imeji
        make
        cd ../..

5. Build kmbmpdc

        xcodebuild -target kmbmpdc -configuration Release

### Code style

[SwiftLint](https://github.com/realm/SwiftLint) is used to enforce code style and conventions.

## License

kmbmpdc is licensed under Apache License 2.0. See `LICENSE` for more details.

libmpdclient is licensed under the revised BSD License. See `libmpdclient/COPYING` for more details.

