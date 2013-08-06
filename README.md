# Plex/Roku

The official Plex client for the Roku. This client is maintained by a
combination of Plex developers and community volunteers. We *love* contributors,
so please don't be shy to fork and hack away.

## Installation

If you're just trying to install the channel normally, you don't need to be
here. You can install the released version of the channel using the Roku
Channel Store. There's also occasionally a test version of the channel
released as a private channel, sort of like a beta. You can install that
using the private channel code `plextest`.

Ok, if you're still reading then you presumably want to install from source
and hopefully make some useful changes. You don't need to download or install
anything from Roku, but you should take a look at Roku's
[developer site](http://www.roku.com/developer). In addition to the downloadable
PDF documentation, you can [browse the docs online](http://sdkdocs.roku.com/).
Roku's docs are well above average.

### Dev Mode

Before you can actually install Roku channels from source, you need to make
sure your Roku is in "dev" mode:

1. Using the Roku remote, press `Home-Home-Home-Up-Up-Right-Left-Right-Left-Right`
2. Choose to Enable the Installer

You only need to do this once, it will remain in dev mode. If you ever want to
exit dev mode you can use the same remote sequence.

### Building and Installing Locally

There's a Makefile that should take care of everything for you. You just need
to set an environment variable with the IP address of your Roku. Assuming
you're in a unix-like environment:

1. `export ROKU_DEV_TARGET=192.168.1.2` (substituting your IP address...)
2. `cd Plex`
3. `make dev install`

There are some additional targets in the Makefile, like `make rel install` to
build a release, but you don't generally need them. One other nicety is the
ability to take a screenshot using `make screenshot`.

### Debugging

The Roku doesn't have logging per se, but dev channels are able to write
messages to a console that you can tail using telnet. It's as simple as

    telnet $ROKU_DEV_TARGET 8085

## Contributing

Did I already mention we love contributors? Please fork and hack away. Let us
know in the forums what you're working on. And of course there's GitHub's
standard notes on how best to contribute:

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Important Notes

### Limit on number of function names

The Roku BrightScript compiler enforces a limit on the number of functions that
can be defined by an app. This is particularly evil because the limit is
different for the 3.x and 4.x firmware--512 and 768 respectively--which makes
it very easy to develop against a Roku 2 and not notice. We've already
exceeded the first gen Roku limit once before, and it's a very ugly crash.

So, any time you add a function, you need to make sure we're not over the limit
and potentially delete another function (or subroutine) to free up a slot.
While we're currently very close to the limit, there are plenty of areas that
could be cleaned up to free some slots.
