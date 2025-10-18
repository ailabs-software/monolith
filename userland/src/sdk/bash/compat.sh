
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
  /system/dart_sdk/bin/dartaotruntime /sdk/trusted/bin/git.aot "$@"
}