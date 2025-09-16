# serial.nim bug on macos: arc/orc cause segfaults
when defined(macos):
  switch("mm", "refc")