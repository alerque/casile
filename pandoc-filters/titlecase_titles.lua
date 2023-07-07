-- Convert all headings to title case following document language rules

local decasify = require("decasify")
local locale = os.getenv("LANGUAGE") or "en"

Pandoc = function (doc)
  local language = pandoc.utils.stringify(doc.meta.language or locale)
  return doc:walk {
    Header = function (element)
      local title = pandoc.utils.stringify(element.content)
      local cased = decasify.titlecase(title, language)
      element.content = cased
      return element
    end
  }
end
