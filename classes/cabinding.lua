local cabook = require("classes.cabook")

local class = pl.class(cabook)
class._name = "cabinding"

local spineoffset = SILE.measurement(CASILE.spine):tonumber() / 2
class.defaultFrameset = {
  front = {
    right = "right(page)",
    width = "50%pw-" .. spineoffset,
    top = "top(page)",
    bottom = "bottom(page)",
    next = "back"
  },
  back = {
    left = "left(page)",
    width = "width(front)",
    top = "top(page)",
    bottom = "bottom(page)",
    next = "spine"
  },
  spine = {
    left = "left(front)",
    top = "top(page)-height(spine)",
    width = "height(page)",
    height = "left(front)-right(back)",
    rotate = 90,
    next = "scratch"
  },
  scratch = { -- controling overflow from the spine is hard
    left = "left(page)",
    top = "bottom(page)",
    width = 0,
    height = 0
  }
}
class.firstContentFrame = "front"

function class:_init (options)

  cabook._init(self, options)

  self:loadPackage("rotate")

  SILE.settings:set("document.parindent", 0, true)
  SILE.settings:set("document.lskip", 0, true)
  SILE.settings:set("document.rskip", 0, true)

  self.packages.tableofcontents.writeToc = function () end

  return self

end

function class:declareOptions ()
  cabook.declareOptions(self)
  self:declareOption("papersize", function (_, size)
    if size then
      self.papersize = size
      local parsed = SILE.papersize(size)
      local spread = parsed[1] * 2 + SILE.measurement(CASILE.spine):tonumber()
      SILE.documentState.paperSize = { spread, parsed[2] }
      SILE.documentState.orgPaperSize = SILE.documentState.paperSize
      SILE.newFrame({
        id = "page",
        left = 0,
        top = 0,
        right = SILE.documentState.paperSize[1],
        bottom = SILE.documentState.paperSize[2]
      })
    end
    return self.papersize
  end)
end

class.setOptions = cabook.setOptions

function class:registerCommands ()

  cabook.registerCommands(self)

  self:registerCommand("meta:surum", function (_, _)
    SILE.typesetter:typeset(CASILE.versioninfo)
  end)

  self:registerCommand("output-right-running-head", function (_, _) end)

end

function class:endPage ()
  SILE.typesetter:chuck()
  cabook.endPage(self)
end

return class