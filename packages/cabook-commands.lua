local base = require("packages.base")

local package = pl.class(base)
package._name = "cabook-commands"

-- luacheck: ignore loadstring
local loadstring = loadstring or load

-- Calculate height of current output queue withouth taking into account any
-- stretch or shrink.
local precalcheight = function()
  local totalHeight = SILE.measurement()
  for _, node in ipairs(SILE.typesetter.state.outputQueue) do
    totalHeight:___add(node.height)
    totalHeight:___add(node.depth)
  end
  return totalHeight
end

function package:_init ()
  base._init(self)
end

function package:registerCommands ()

  self:registerCommand("cabook:chapter:post", function (options, _)
    options.weight = SU.boolean(options.decorate, true)
    SILE.call("novbreak")
    SILE.call("medskip")
    SILE.call("novbreak")
    if options.flourish then
      SILE.call("center", {} , function ()
        SILE.call("novbreak")
        SILE.call("font", { family = "IM FELL FLOWERS 2", size = "9pt" }, function ()
          SILE.call("skip", { height = "-3pt" })
          SILE.typesetter:typeset("a")
          SILE.call("medskip")
        end)
      end)
    end
  end)

  self:registerCommand("cabook:part:pre", function () end)

  self:registerCommand("cabook:part:post", function ()
    SILE.call("fluent", {}, { "cabook-part-post" })
    SILE.call("par")
  end)

  self:registerCommand("cabook:subparagraph:post", function () end)

  self:registerCommand("tableofcontents:header", function (options, _)
    options.rule = SU.boolean(options.rule, true)
    SILE.call("center", {}, function ()
      SILE.call("hbox", {}, function ()
        SILE.call("skip", { height = "12ex" })
        SILE.call("tableofcontents:headerfont", { height = "12ex" }, function ()
          SILE.call("fluent", {}, { "toc-title "})
        end)
      end)
    end)
    SILE.call("bigskip")
    if options.rule then
      SILE.call("fullrule", { raise = 0 })
      SILE.call("bigskip")
    end
  end)

  self:registerCommand("tableofcontents:footer", function ()
    SILE.call("vfill")
    SILE.call("break")
  end)

  self:registerCommand("wraptitle", function (_, content)
    SILE.process(content)
  end)

  self:registerCommand("wrapsubtitle", function (_, content)
    SILE.process(content)
  end)

  self:registerCommand("left-running-head", function (_, content)
    SILE.scratch.headers.left = content
  end, "Text to appear on the top of the left page")

  self:registerCommand("right-running-head", function (_, content)
    SILE.scratch.headers.right = content
  end, "Text to appear on the top of the right page")

  self:registerCommand("output-right-running-head", function (_, _)
    if not SILE.scratch.headers.right then return end
    SILE.typesetNaturally(SILE.getFrame("runningHead"), function ()
      SILE.settings:set("current.parindent", SILE.nodefactory.glue())
      SILE.settings:set("typesetter.parfillskip", SILE.nodefactory.glue())
      SILE.settings:set("document.lskip", SILE.nodefactory.glue())
      SILE.settings:set("document.rskip", SILE.nodefactory.glue())
      SILE.call("cabook:font:right-header", {}, function ()
        SILE.process(SILE.scratch.headers.right)
        SILE.call("hfill")
        SILE.call("cabook:font:folio", {}, function ()
          SILE.typesetter:typeset(self.class.packages.counters:formatCounter(SILE.scratch.counters.folio))
        end)
      end)
      SILE.typesetter:leaveHmode()
      SILE.call("skip", { height = "-8pt" })
      SILE.call("fullrule", { raise = 0 })
    end)
  end)

  self:registerCommand("output-left-running-head", function (_, _)
    if not SILE.scratch.headers.left then return end
    SILE.typesetNaturally(SILE.getFrame("runningHead"), function ()
      SILE.settings:set("typesetter.parfillskip", SILE.nodefactory.glue())
      SILE.settings:set("current.parindent", SILE.nodefactory.glue())
      SILE.settings:set("document.lskip", SILE.nodefactory.glue())
      SILE.settings:set("document.rskip", SILE.nodefactory.glue())
      SILE.call("cabook:font:left-header", {}, function ()
        SILE.call("cabook:font:folio", {}, function ()
          SILE.typesetter:typeset(self.class.packages.counters:formatCounter(SILE.scratch.counters.folio))
        end)
        SILE.call("hfill")
        SILE.call("meta:title")
      end)
      SILE.typesetter:leaveHmode()
      SILE.call("skip", { height = "-8pt" })
      SILE.call("fullrule", { raise = 0 })
    end)
  end)

  self:registerCommand("aki", function ()
    SILE.call("penalty", { penalty = -1 })
  end)

  self:registerCommand("book:sectioning", function (options, content)
    content = SU.subContent(content)
    options.skiptoc = SU.boolean(options.skiptoc, false)
    options.numbering = SU.boolean(options.numbering, true)
    options.reset = SU.boolean(options.reset, false)
    local level = SU.required(options, "level", "book:sectioning")
    if options.numbering then
      SILE.call("increment-multilevel-counter", {
          id = "sectioning",
          level = options.level,
          display = options.display,
          reset = options.reset
        })
      local toc_content = {}
      for k, v in pairs(content) do
        toc_content[k] = v
      end
      local counters = SILE.scratch.counters["sectioning"]
      if level == 1 then
        local val = self.class.packages.counters:formatCounter({ display = "ORDINAL", value = counters.value[level] })
        toc_content[1] = val .. " KISIM: " .. self.class.uppercase(content[1] or "")
      elseif level == 2 then
        local val = self.class.packages.counters:formatCounter({ display = "arabic", value = counters.value[level] })
        toc_content[1] = val .. ". " .. content[1]
      end
      if options.prenumber then
        if SILE.Commands["book:chapter:precounter"] then SILE.call("book:chapter:precounter") end
        SILE.call(options.prenumber)
      end
      SILE.call("show-multilevel-counter", { id = "sectioning", display = options.display, minlevel = level, level = level })
      if options.postnumber then
        SILE.call(options.postnumber)
      end
      local number = self.class.packages.counters:formatCounter({ display = "arabic", value = counters.value[level] })
      if not options.skiptoc then SILE.call("tocentry", { level = options.level, number = tonumber(number) }, toc_content) end
    else
      if not options.skiptoc then SILE.call("tocentry", { level = options.level, number = false }, content) end
    end
  end)

  self:registerCommand("tocentry", function (options, content)
    SILE.call("info", {
      category = "toc",
      value = {
        label = content,
        number = options.number,
        skiptoc = options.skiptoc,
        level = (options.level or 1)
      }
    })
  end)

  -- This is similar to SILE's open-double-page, but disables headers and folios
  -- on blank pages and allows opening the even side (with or without a leading blank)
  self:registerCommand("open-spread", function (options)
    local odd = SU.boolean(options.odd, not CASILE.isScreenLayout())
    local double = SU.boolean(options.double, not CASILE.isScreenLayout())
    local count = 0
    local pageHook = function () count = count + 1 end
    self.class:registerHook("newpage", pageHook)
    repeat
      SILE.typesetter:leaveHmode()
      if count > 0 then
        SILE.call("hbox")
        SILE.typesetter:leaveHmode()
        SILE.scratch.headers.skipthispage = true
        SILE.scratch.counters.folio.off = 2
      end
      SILE.call("supereject")
      SILE.typesetter:leaveHmode()
    until (not double or count > 1) and (odd and self.class:oddPage()) or (not odd and not self.class:oddPage())
    table.remove(SILE.typesetter.hooks.pageend)
  end)

  self:registerCommand("chaptertoc", function (_, _)
    local thischapter = SILE.scratch.counters.sectioning.value[2]
    if thischapter < 1 then return end
    SILE.call("section", { numbering = false }, { "Bölümdekiler" })
    local tocfile,_ = io.open(SILE.masterFilename .. '.toc')
    if not tocfile then return end
    local doc = tocfile:read("*all")
    local toc = assert(loadstring(doc))()
    local zone = false
    for _, item in pairs(toc) do
      if zone and item.level > 2 then
        SILE.call("tableofcontents:item", {
            chaptertoc = true,
            level = item.level,
            number = item.number,
            pageno = item.pageno
          }, item.label)
      end
      if item.level == 2 then zone = item.number == thischapter end
    end
  end)

  self:registerCommand("tableofcontents", function (_, _)
    local tocfile,_ = io.open(SILE.masterFilename .. '.toc')
    if not tocfile then
      SILE.call("tableofcontents:notocmessage")
      return
    end
    local doc = tocfile:read("*all")
    local toc = assert(loadstring(doc))()
    local haschapters = false
    for i = 1, #toc do
      if toc[i].level == 2 then
        haschapters = true
      end
    end
    if not haschapters then return end
    SILE.call("tableofcontents:header")
    for _, item in ipairs(toc) do -- pairs turns things back in the wrong order sometime
      if not item.skiptoc then
        SILE.call("tableofcontents:item", {
            chaptertoc = false,
            level = item.level,
            number = item.number,
            pageno = item.pageno
          }, item.label)
      end
    end
    SILE.call("tableofcontents:footer")
  end)

  self:registerCommand("tableofcontents:item", function (options, content)
    options.dotfill = SU.boolean(options.dotfill, true)
    SILE.settings:temporarily(function ()
      SILE.settings:set("typesetter.parfillskip", SILE.nodefactory.glue())
      SILE.call("tableofcontents:level"..options.level.."item", options, function ()
        SILE.process(CASILE.addDiscressionaryBreaks({}, content))
        if options.level == 2 then
          SILE.call("hbox", {}, function ()
            if options.dotfill then SILE.call("dotfill") else SILE.call("hfill") end
            SILE.typesetter:typeset(options.pageno)
          end)
        else
          SILE.call("hss")
        end
      end)
    end)
  end)

  self:registerCommand("tableofcontents:level1item", function (_, content)
    SILE.call("bigskip")
    SILE.settings:temporarily(function ()
      SILE.settings:set("current.parindent", SILE.nodefactory.glue())
      SILE.settings:set("document.lskip", SILE.nodefactory.glue())
      SILE.settings:set("document.rskip", SILE.nodefactory.glue())
      SILE.call("cabook:font:sans", { size = "10pt", weight = 600 }, content)
    end)
  end)

  self:registerCommand("tableofcontents:level2item", function (_, content)
    SILE.call("skip", { height = "4.5pt" })
    SILE.settings:set("current.parindent", SILE.nodefactory.glue())
    SILE.settings:set("document.lskip", SILE.nodefactory.glue("5ex"))
    SILE.settings:set("document.rskip", SILE.nodefactory.glue("3em"))
    SILE.settings:set("typesetter.parfillskip", SILE.nodefactory.glue("-2em"))
    SILE.call("glue", { width = "-2ex" })
    SILE.call("font", { size = "11pt" }, content)
    SILE.call("break")
    SILE.call("skip", { height = 0 })
  end)

  self:registerCommand("tableofcontents:level3item", function (_, content)
    SILE.call("skip", { height = "4.5pt" })
    SILE.settings:set("current.parindent", SILE.nodefactory.glue())
    SILE.settings:set("document.lskip", SILE.nodefactory.glue("5ex"))
    SILE.settings:set("document.rskip", SILE.nodefactory.glue("3em"))
    SILE.settings:set("typesetter.parfillskip", SILE.nodefactory.glue("-2em"))
    SILE.call("glue", { width = "-2ex" })
    SILE.call("font", { size = "10pt" }, content)
    SILE.call("break")
    SILE.call("skip", { height = 0 })
  end)

  self:registerCommand("tableofcontents:level4item", function (_, content)
    SILE.call("skip", { height = "4.5pt" })
    SILE.settings:set("current.parindent", SILE.nodefactory.glue())
    SILE.settings:set("document.lskip", SILE.nodefactory.glue("5ex"))
    SILE.settings:set("document.rskip", SILE.nodefactory.glue("3em"))
    SILE.settings:set("typesetter.parfillskip", SILE.nodefactory.glue("-2em"))
    SILE.call("glue", { width = "-2ex" })
    SILE.call("font", { size = "9pt" }, content)
    SILE.call("break")
    SILE.call("skip", { height = 0 })
  end)

  self:registerCommand("tableofcontents:level5item", function (_, content)
    SILE.call("skip", { height = "4.5pt" })
    SILE.settings:set("current.parindent", SILE.nodefactory.glue())
    SILE.settings:set("document.lskip", SILE.nodefactory.glue("5ex"))
    SILE.settings:set("document.rskip", SILE.nodefactory.glue("3em"))
    SILE.settings:set("typesetter.parfillskip", SILE.nodefactory.glue("-2em"))
    SILE.call("glue", { width = "-2ex" })
    SILE.call("font", { size = "9pt" }, content)
    SILE.call("break")
    SILE.call("skip", { height = 0 })
  end)

  self:registerCommand("footnote", function (options, content)
    options.indent = options.indent or "14pt"
    SILE.call("footnotemark")
    local opts = SILE.scratch.insertions.classes.footnote
    local f = SILE.getFrame(opts["insertInto"].frame)
    local oldT = SILE.typesetter
    SILE.typesetter = SILE.typesetter {}
    SILE.typesetter:init(f)
    SILE.typesetter.getTargetLength = function () return SILE.length(0xFFFFFF) end
    SILE.settings:pushState()
    SILE.settings:reset()
    SILE.settings:set("linespacing.method", "fit-font")
    SILE.settings:set("linespacing.fit-font.extra-space", SILE.length("0.05ex plus 0.1pt minus 0.1pt"))
    SILE.settings:set("document.lskip", SILE.nodefactory.glue(options.indent))
    local material = SILE.call("vbox", {}, function ()
      SILE.call("cabook:font:footnote", {}, function ()
        SILE.call("footnote:counter", options, content)
        -- don't justify footnotes
        SILE.call("raggedright", {}, function ()
          --inhibit hyphenation in footnotes
          SILE.call("font", { language = "und" }, content)
        end)
      end)
    end)
    SILE.settings:popState()
    SILE.typesetter = oldT
    self.class:insert("footnote", material)
    SILE.scratch.counters.footnote.value = SILE.scratch.counters.footnote.value + 1
  end)

  self:registerCommand("footnote:counter", function (options, _)
    SILE.call("noindent")
    local width = SILE.length(options.indent)
    SILE.typesetter:pushGlue({ width = width:negate() })
    SILE.call("rebox", { width = tostring(width) }, function ()
      SILE.typesetter:typeset(self.class.packages.counters:formatCounter(SILE.scratch.counters.footnote) .. ".")
    end)
  end)

  self:registerCommand("font:la", function (options, content)
    options.style = options.style or "Italic"
    SILE.call("font", options, content)
  end)

  self:registerCommand("font:el", function (options, content)
    options.style = options.style or "Italic"
    SILE.call("font", options, content)
  end)

  self:registerCommand("lang", function (options, content)
    local language = options.language or "und"
    local fontfunc = SILE.Commands["font:" .. language] and "font:" .. language or "font"
    SILE.call(fontfunc, { language = language }, content)
  end)

  self:registerCommand("langund", function (_, content)
    SILE.call("lang", {}, content)
  end)

  self:registerCommand("langel", function (_, content)
    SILE.call("lang", { language = "el" }, content)
  end)

  self:registerCommand("langla", function (_, content)
    SILE.call("lang", { language = "la" }, content)
  end)

  self:registerCommand("langen", function (_, content)
    SILE.call("lang", { language = "en" }, content)
  end)

  self:registerCommand("langde", function (_, content)
    SILE.call("lang", { language = "de" }, content)
  end)

  self:registerCommand("langfr", function (_, content)
    SILE.call("lang", { language = "fr" }, content)
  end)

  self:registerCommand("langnl", function (_, content)
    SILE.call("lang", { language = "nl" }, content)
  end)

  self:registerCommand("langhe", function (_, content)
    SILE.call("lang", { language = "he" }, content)
  end)

  self:registerCommand("quote", function (options, content)
    options.setback = SILE.length(options.setback or SILE.settings:get("document.parindent"))
    SILE.call("skip", { height = "0.5bs" })
    SILE.settings:pushState()
    SILE.settings:temporarily(function ()
      SILE.settings:set("document.rskip", options.setback)
      SILE.settings:set("document.lskip", options.setback)
      SILE.settings:set("current.parindent", 0)
      SILE.settings:set("document.parindent", 0)
      SILE.settings:set("document.parskip", "1.5ex")
      SILE.process(content)
      SILE.settings:set("document.parskip")
      SILE.typesetter:pushGlue(SILE.nodefactory.hfillglue())
      SILE.call("novbreak")
      SILE.call("par")
      SILE.call("novbreak")
    end)
    SILE.settings:popState()
    SILE.call("skip", { height = "0.5bs" })
    SILE.call("novbreak")
    SILE.call("noindent")
  end, "Typeset quotation blocks")

  self:registerCommand("excerpt", function ()
    SILE.call("font", { size = "0.975em" })
    SILE.settings:set("linespacing.fit-font.extra-space", SILE.length("0.675ex plus 0.05ex minus 0.05ex"))
  end)

  self:registerCommand("verse", function ()
    if SILE.scratch.last_was_ref then
      SILE.call("skip", { height = "-3en" })
    end
    SILE.scratch.last_was_ref = false
    SILE.call("font", { family = "Libertinus Serif", weight = 400, style = "Italic", features = "+salt,+ss02,+onum,+liga,+dlig,+clig" })
    SILE.settings:set("linespacing.fit-font.extra-space", SILE.length("0.25ex plus 0.05ex minus 0.05ex"))
  end)

  self:registerCommand("poetry", function ()
    SILE.settings:set("document.lskip", SILE.nodefactory.glue("30pt"))
    SILE.settings:set("document.rskip", SILE.nodefactory.hfillglue())
    SILE.settings:set("current.parindent", SILE.nodefactory.glue())
    SILE.settings:set("typesetter.parfillskip", SILE.nodefactory.glue())
  end)

  self:registerCommand("dedication", function (options, content)
    SILE.settings:temporarily(function ()
      SILE.call("class:dedication", options, content)
    end)
  end)

  self:registerCommand("class:dedication", function (options, content)
    options.eject = SU.boolean(options.eject, true)
    SILE.scratch.headers.skipthispage = true
    SILE.scratch.counters.folio.off = 2
    SILE.call("center", {}, function ()
      SILE.settings:set("linespacing.method", "fit-font")
      SILE.settings:set("linespacing.fit-font.extra-space", SILE.length("0.4ex plus 0.1ex minus 0.1ex"))
      SILE.call("topfill")
      SILE.call("cabook:font:dedication", {}, content)
    end)
    if options.eject then SILE.call("eject") end
  end)

  self:registerCommand("seriespage:series", function (_, content)
    SILE.call("center", {}, function ()
      SILE.call("cabook:font:chaptertitle", {}, function ()
        SILE.process(content)
        SILE.call("aki")
        SILE.typesetter:typeset(" Serisi’ndeki Yayınlar")
        SILE.call("cabook:chapter:post")
      end)
    end)
  end)

  self:registerCommand("seriespage:pre", function (_, _)
    SILE.call("open-spread", { odd = true, double = false })
    SILE.scratch.headers.skipthispage = true
    SILE.scratch.counters.folio.off = 2
    SILE.call("topfill")
  end)

  -- Make this a function because we want to override it in some layouts
  self:registerCommand("topfill", function (_, _)
    SILE.typesetter:leaveHmode()
    SILE.call("hbox")
    SILE.call("vfill")
  end)

  self:registerCommand("seriespage:title", function (options, content)
    SILE.call("raggedright", {}, function ()
      SILE.settings:set("current.parindent", SILE.nodefactory.glue("-2em"))
      SILE.settings:set("document.lskip", SILE.nodefactory.glue("2em"))
      SILE.settings:set("linespacing.method", "fixed")
      SILE.settings:set("linespacing.fixed.baselinedistance", SILE.length("3ex plus 1ex minus 0.5ex"))
      if not options.author then
        SILE.call("font", { style = "Italic", language = "und" }, content)
        SILE.call("medskip")
      else
        SILE.call("font", { weight = "600", language = "und" }, content)
        SILE.typesetter:typeset(" ")
        SILE.call("aki")
        SILE.typesetter:typeset("— ")
        SILE.call("font", { style = "Italic", language = "und" }, function ()
          SILE.typesetter:typeset(options.author)
        end)
        SILE.call("smallskip")
      end
    end)
  end)

  self:registerCommand("criticHighlight", function (_, content)
    SILE.settings:temporarily(function ()
      SILE.call("font", { weight = 600 })
      SILE.call("color", { color = "#0000E6" }, content)
    end)
  end)

  self:registerCommand("criticComment", function (_, content)
    SILE.settings:temporarily(function ()
      SILE.call("font", { style = "Italic" })
      SILE.call("color", { color = "#bdbdbd" }, function ()
        SILE.typesetter:typeset(" (")
        SILE.process(content)
        SILE.typesetter:typeset(")")
      end)
    end)
  end)

  self:registerCommand("criticAdd", function (_, content)
    SILE.settings:temporarily(function ()
      SILE.call("font", { weight = 600 })
      SILE.call("color", { color = "#0E7A00" }, content)
    end)
  end)

  self:registerCommand("criticDel", function (_, content)
    SILE.settings:temporarily(function ()
      SILE.call("font", { weight = 600 })
      SILE.call("color", { color = "#E60000" }, content)
    end)
  end)

  self:registerCommand("addDiscressionaryBreaks", function (options, content)
    SILE.process(CASILE.addDiscressionaryBreaks(options, content))
  end, "Try to find good breakpoints based on punctuation")

  self:registerCommand("pubDateFormat", function (_, content)
    local input = SU.contentToString(content)
    local date = {}
    for m in input:gmatch("(%d+)") do table.insert(date, tonumber(m)) end
    local ts = os.time({ year = date[1] or 1970, month = date[2] or 1, day = date[3] or 1 })
    SILE.call("date", { format = "%B %Y", time = ts, locale = "tr_TR.utf-8" })
  end, "Output publication dates in proper format for imprint page")

  self:registerCommand("requireSpace", function (options, content)
    local required = SILE.length(options.height or 0)
    SILE.typesetter:leaveHmode()
    SILE.call("hbox", {}, content) -- push content we want to fit
    local heightOfPageSoFar = SILE.pagebuilder:collateVboxes(SILE.typesetter.state.outputQueue).height
    local heightOfFrame = SILE.typesetter.frame:height()
    table.remove(SILE.typesetter.state.nodes) -- steal it back
    if heightOfFrame - heightOfPageSoFar < required then
      SILE.call("supereject")
    end
  end)

  self:registerCommand("lpad", function (options, content)
    local width = SILE.length(options.width)
    local nodes = SILE.typesetter.state.nodes
    local hbox = SILE.call("hbox", {}, content)
    nodes[#nodes] = nil
    SILE.call("glue", { width = width:absolute() - hbox.width:absolute() })
    nodes[#nodes+1] = hbox
    return hbox
  end)

  self:registerCommand("skipto", function (options, _)
    local targetHeight = SU.cast("measurement", options.height):tonumber()
    SILE.call("hbox")
    SILE.typesetter:leaveHmode()
    local queueHeight = precalcheight()
    table.remove(SILE.typesetter.state.nodes)
    SILE.call("skip", { height = targetHeight - queueHeight })
  end)

end

return package
