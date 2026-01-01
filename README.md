# OpusRemux

A simple remuxer that takes the opus data in a `.ogg` file and puts it in a `.m4a` container.

## Why?

The native audio playback solutions in modern Apple SDKs can actually playback the opus encoded audio directly, but it **must** be in a `m4a` container. Using this remuxer enables such use cases.

As there is no conversions on the actual audio data, file sizes are comparable to the original (often only very slightly larger), without any quality losses. OpusRemux does not output typical AAC encoded `m4a` files.

## Are you sure m4a containers can encapsulate Opus data?

Yes. Check out https://www.opus-codec.org/docs/opus_in_isobmff.html

## Usage example
```Swift
import OpusRemux

let source: URL = ... // your .ogg file
let destination: URL = ... // where the .m4a file should go

try Remuxer.remux(source: source, destination: destination)
```

## Limitations

Testing on watchOS have revealed that while `AVAudioPlayer` does play the opus data encapsulated `m4a` files, which are generated using this package just fine, it is unable to seek forwards or backwards.

## Dependencies
- [SwiftOgg](https://github.com/vincentneo/SwiftOgg): A wrapper for [xiph/libogg](https://github.com/xiph/ogg).

## Contributions
If you ever spot any mistake, please feel free to open a pull request! All contributions are welcome.

## AI Usage Disclosure

The development of this package utilised the following LLMs:
  - Google Gemini 3 Pro
  - Claude Opus 4.5
