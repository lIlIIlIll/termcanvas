#!/bin/sh
# Finite RGBA fixtures for the public decoder tests. No file writes or children.
case "$4" in
  one-frame) count=1 ;;
  many-frames) count=257 ;;
  partial-frame) printf x; exit 0 ;;
  selected-frame)
    pixel='\377\000\000\377'
    for arg in "$@"; do
      case "$arg" in *'select=eq(n\,7)'*) pixel='\000\000\377\377' ;; esac
    done
    i=0
    while [ "$i" -lt 128 ]; do printf "$pixel"; i=$((i + 1)); done
    exit 0
    ;;
  *) exit 1 ;;
esac
i=0
while [ "$i" -lt "$count" ]; do
  printf '\377\377\377\377'
  i=$((i + 1))
done
