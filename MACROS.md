# Additionals macro

## Youtube

Youtube wiki macro for Redmine.

### {{youtube(video [, width=WIDTH, height=HEIGHT, autoplay=BOOL])}}

Show Youtube embedded video

- :param string video: Youtube video code, e.g. wvsboPUjrGc. This is the part after <https://www.youtube.com/watch?v=>
- :param int width: video width
- :param int height: video height
- :param bool autoplay: auto play video, if true

### Scope

This macro works in all text fields with formatting support.

### Examples

Youtube video with video ``wvsboPUjrGc`` (iframe) and default size 640x360

```text
  {{youtube(wvsboPUjrGc)}}
```

Youtube video with size 853x480

```text
  {{youtube(wvsboPUjrGc, width=853, height=480)}}
```

Youtube video with auto play

```text
  {{youtube(wvsboPUjrGc, autoplay=true)}}
```
