switch("define", "release")
switch("threads", "off")
switch("opt", "size")


task test, "runs the test suite":
  for name in listFiles("./tests"):
    exec("nim r " & name)


task clean, "deletes the previously built binary":
  const bin = "avrman"
  if fileExists bin:
    rmFile bin


# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
