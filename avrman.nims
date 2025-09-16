# serial.nim bug on macos: arc/orc cause segfaults
when defined(macosx):
  switch("mm", "refc")