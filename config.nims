switch("define", "release")
switch("threads", "off")
switch("opt", "size")

# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
