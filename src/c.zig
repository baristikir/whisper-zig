pub usingnamespace @cImport({
    @cDefine("_GNU_SOURCE", "");
    @cInclude("whisper.h");
    @cInclude("dr_wav.h");
});
