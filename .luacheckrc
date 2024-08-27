std = "lua54+sile"

max_line_length = false

include_files = {
   "**/*.lua",
   "**/*.lua.in",
   "*.rockspec",
   ".busted",
   ".luacheckrc",
}

exclude_files = {
   "casile-*",
   "lua_modules",
   "lua-libraries",
   ".lua",
   ".luarocks",
   ".install",
}

files["spec"] = {
   std = "+busted",
}

files["pandoc-filters"] = {
   std = "+pandoc_filter",
}

files["lib"] = {
   std = "+pandoc_reader+pandoc_writer",
}
