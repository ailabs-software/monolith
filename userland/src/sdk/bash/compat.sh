
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

# trusted command wrappers for use in bash
function git()
{
  # run git through user exec service so runs as trusted command
  /system/dart_sdk/bin/dartaotruntime /system/bin/run.aot git "$@"
}

function dart()
{
  # run dart through user exec service so runs as trusted command
  /system/dart_sdk/bin/dartaotruntime /system/bin/run.aot /opt/monolith/core/dart_sdk/bin/dart "$@"
}
