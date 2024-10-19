# Whisper.cpp with Zig

This repository demonstrates the usage of
[whisper.cpp](https://github.com//ggerganov/whisper.cpp) in Zig.

# Usage

First download a Whisper model from
[huggingface](https://huggingface.co/ggerganov/whisper.cpp).

```shell
$ ./whisper.cpp/models/download-ggml.sh base.en
$ zig build && ./zig-out/bin/whisper-zig -- -m ggml-base.en.bin -f ./whisper.cpp/samples/jfk.wav
```

## Tests

```shell
$ ./whisper.cpp/models/download-ggml.sh base.en
$ zig build test
```

# Sources

- [whisper.cpp](https://github.com//ggerganov/whisper.cpp)
- [dr_wav](https://github.com/mackron/dr_libs)
