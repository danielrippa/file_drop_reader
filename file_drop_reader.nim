
type

  Point = object
    x,y: int32

  DropFiles = object
    pFiles: int32
    pt: Point
    fNC, fWide: int32

proc open_clipboard(hWnd: int = 0): cint   {.stdcall, dynlib: "user32", importc: "OpenClipboard", discardable.}
proc close_clipboard(): cint               {.stdcall, dynlib: "user32", importc: "CloseClipboard", discardable.}

proc get_clipboard_data(format: uint): pointer    {.stdcall, dynlib: "user32", importc: "GetClipboardData".}

proc clipboard_format_available(format: uint): cint    {.stdcall, dynlib: "user32", importc: "IsClipboardFormatAvailable".}

proc global_size(mem: pointer): cint       {.stdcall, dynlib: "kernel32", importc: "GlobalSize".}
proc global_lock(mem: pointer): pointer    {.stdcall, dynlib: "kernel32", importc: "GlobalLock".}
proc global_unlock(mem: pointer): cint     {.stdcall, dynlib: "kernel32", importc: "GlobalUnlock".}

when not defined(clip):

  type

    clip_formats = enum
      text=1,
      bitmap,
      metafile_picture,
      symbolic_link,
      dif,
      tiff,
      oem_text,
      dib,
      palette,
      pen_data,
      riff,
      wave_audio,
      unicode_text,
      enhanced_metafile,
      file_drop,
      locale,
      dib_v5

    ClipFragment = tuple[format: clip_formats, data: seq[byte]]

    clip = object

  template formats(_: type clip): auto = clip_formats
  template fragment(_: type clip): auto = ClipFragment

  using
    c: type clip
    format: clip.formats

  #

  proc contains_file_drop_list(c): bool {.inline.} =
    clip.contains_data clip.formats.file_drop

  proc contains_data(c, format): bool {.inline.} =
    format.uint.clipboard_format_available != 0

  #

  proc `$`(src: clip.fragment): string =
    var utf16 = src.data
    return $cast[WideCString](utf16[0].addr)

  converter to_drop_list(src: clip.fragment): seq[string] =
    result = newSeq[string](0)

    var feed = src.data
    var utf16_feed = cast[seq[int16]](feed)
    utf16_feed.setLen feed.len

    if feed.len > 0:

      var
        header = cast[ptr DropFiles](feed[0].addr)
        accum: seq[int16] = @[]

      for idx, byte in feed[header.pFiles..^1]:

        let c = (if header.fWide == 0: byte.int16 else: utf16_feed[ idx+header.pFiles shr 1])
        if c != 0:

          accum &= c

        elif accum != @[]:

          accum.setLen accum.len * 2
          result.add($(format: clip.formats.text, data: cast[seq[byte]](accum)))

          accum = @[]

  proc get_file_drop_list(c): seq[string] {.inline.} =
    clip.get_data clip.formats.file_drop

  proc get_data(c, format): clip.fragment {.inline.} =
    clip.get_data_list(format)[0]

  proc get_data_list(c; formats: varargs[clip.formats]): seq[clip.fragment] =

    result = newSeq[clip.fragment](0)

    open_clipboard()

    for format in formats:

      let data = format.uint.get_clipboard_data
      let data_size = data.global_size

      if data_size > 0:

        let feed = data.global_lock
        var buffer = newSeq[byte](data_size)
        buffer[0].addr.copyMem feed, data_size
        discard data.global_unlock

        result.add (format, buffer)

      else:

        result.add (format, @[])

    close_clipboard()

if clip.contains_file_drop_list:
  for file in clip.get_file_drop_list:
    echo file
