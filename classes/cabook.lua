local book = require("classes/book")
local plain = require("classes/plain")

local cabook = pl.class(book)
cabook._name = "cabook"

function cabook:_init (options)
  book._init(self, options)
  self:loadPackage("color")
  self:loadPackage("ifattop")
  self:loadPackage("leaders")
  self:loadPackage("raiselower")
  self:loadPackage("rebox");
  self:loadPackage("rules")
  self:loadPackage("image")
  self:loadPackage("date")
  self:loadPackage("textcase")
  self:loadPackage("frametricks")
  self:loadPackage("inputfilter")
  self:loadPackage("linespacing")
  if self.options.verseindex then
    self:loadPackage("verseindex")
  end
  self:loadPackage("imprint")
  self:loadPackage("covers")
  self:loadPackage("cabook-commands")
  self:loadPackage("cabook-inline-styles")
  self:loadPackage("cabook-block-styles")
  self:registerPostinit(function (_)
    -- CaSILE books sometimes have sections, sometimes don't.
    -- Initialize some sectioning levels to work either way
    SILE.scratch.counters["sectioning"] = {
      value =  { 0, 0 },
      display = { "ORDINAL", "STRING" }
    }
    require("hyphenation_exceptions")
    SILE.settings:set("typesetter.underfulltolerance", SILE.length("6ex"))
    SILE.settings:set("typesetter.overfulltolerance", SILE.length("0.2ex"))
    table.insert(SILE.input.preambles, function ()
      SILE.call("footnote:separator", {}, function ()
        SILE.call("rebox", { width = "6em", height = "2ex" }, function ()
          SILE.call("hrule", { width = "5em", height = "0.2pt" })
        end)
        SILE.call("medskip")
      end)
      SILE.call("cabook:font:serif", { size = "11.5pt" })
    end)
    SILE.settings:set("linespacing.method", "fit-font")
    SILE.settings:set("linespacing.fit-font.extra-space", SILE.length("0.6ex plus 0.2ex minus 0.2ex"))
    SILE.settings:set("linebreak.hyphenPenalty", 300)
    SILE.scratch.insertions.classes.footnote.interInsertionSkip = SILE.length("0.7ex plus 0 minus 0")
    SILE.scratch.last_was_ref = false
    SILE.typesetter:registerPageEndHook(function ()
      SILE.scratch.last_was_ref = false
    end)
  end)
end

function cabook:declareSettings ()
  book.declareSettings(self)
end

function cabook:declareOptions ()
  book.declareOptions(self)
  local binding, crop, background, verseindex, layout
  self:declareOption("binding", function (_, value)
      if value then binding = value end
      return binding
    end)
  self:declareOption("crop", function (_, value)
      if value then crop = SU.cast("boolean", value) end
      return crop
    end)
  self:declareOption("background", function (_, value)
      if value then background = SU.cast("boolean", value) end
      return background
    end)
  self:declareOption("verseindex", function (_, value)
      if value then verseindex = SU.cast("boolean", value) end
      return verseindex
    end)
  self:declareOption("layout", function (_, value)
    if value then
      layout = value
      self:registerPostinit(function (_)
          require("layouts."..layout)(self)
        end)
    end
    return layout
    end)
end

function cabook:setOptions (options)
  options.binding = options.binding or "print" -- print, paperback, hardcover, coil, stapled
  options.crop = options.crop or true
  options.background = options.background or true
  options.verseindex = options.verseindex or false
  options.layout = options.layout or "a4"
  book.setOptions(self, options)
end

function cabook:registerCommands ()
  book.registerCommands(self)
end

function cabook:endPage ()
  if not SILE.scratch.headers.skipthispage then
    SILE.settings:pushState()
    SILE.settings:reset()
    if self:oddPage() then
      SILE.call("output-right-running-head")
    else
      SILE.call("output-left-running-head")
    end
    SILE.settings:popState()
  end
  SILE.scratch.headers.skipthispage = false
  return plain.endPage(self)
end

return cabook
