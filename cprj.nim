import std/strutils
import std/os


const
  make_tpl   = staticRead("./templates/c/make_tpl")
  makef_tpl  = staticRead("./templates/c/make_flash_tpl")
  cmake_tpl  = staticRead("./templates/c/cmake_tpl")
  cmakef_tpl = staticRead("./templates/c/cmake_flash_tpl")
  git_tpl    = staticRead("./templates/c/gitignore")
  main_tpl   = staticRead("./templates/c/main.c")


proc generate_project*(mcu, fcpu, prog, proj: string, cmake: bool) =
  if dirExists(proj):
    stdout.writeLine "a directory with the current project name already exists"
    quit(1)

  createDir(proj)
  setCurrentDir(proj)

  if cmake:
    if prog == "":
      writeFile("CMakeLists.txt", cmake_tpl  % [mcu, fcpu])
    else:
      writeFile("CMakeLists.txt", cmakef_tpl % [mcu, fcpu, prog])
  else:
    if prog == "":
      writeFile("Makefile", make_tpl  % [mcu, fcpu])
    else:
      writeFile("Makefile", makef_tpl % [mcu, fcpu, prog])
  
  writeFile(".gitignore", git_tpl)

  createDir("inc")
  createDir("src")
  setCurrentDir("./src")
  writeFile("main.c", main_tpl)
