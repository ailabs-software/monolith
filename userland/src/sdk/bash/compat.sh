
function bash()
{
  /sdk/bash/lib/bash.exe "$@"
}

function basename()
{
  /system/bin/busybox.exe basename "$@"
}

function dirname()
{
  /system/bin/busybox.exe dirname "$@"
}

function mkdir()
{
  /system/bin/busybox.exe mkdir "$@"
}

function rm()
{
  /system/bin/busybox.exe rm "$@"
}

function cp()
{
  /system/bin/busybox.exe cp "$@"
}

function mv()
{
  /system/bin/busybox.exe mv "$@"
}

function find()
{
  /system/bin/busybox.exe find "$@"
}

function chmod()
{
  /system/bin/busybox.exe chmod "$@"
}

# trusted command wrappers for use in bash
function cook()
{
  # run dart through user exec service so runs as trusted command
  /system/dart_sdk/bin/dartaotruntime /system/bin/run.aot cook "$@"
}

function dart()
{
  # run dart through user exec service so runs as trusted command
  /system/dart_sdk/bin/dartaotruntime /system/bin/run.aot dart "$@"
}

function git()
{
  # run git through user exec service so runs as trusted command
  /system/dart_sdk/bin/dartaotruntime /system/bin/run.aot git "$@"
}

function docker()
{
  # run docker through user exec service so runs as trusted command
  /system/dart_sdk/bin/dartaotruntime /system/bin/run.aot docker "$@"
}

function tar()
{
  # run tar through user exec service so runs as trusted command
  /system/dart_sdk/bin/dartaotruntime /system/bin/run.aot tar "$@"
}
