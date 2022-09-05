return function (class)

  class.options.papersize = "135mm x 195mm"

  if class._name == "cabook" then

    class.defaultFrameset = {
      content = {
        left = "left(page) + 22.5mm",
        right = "right(page) - 15mm",
        top = "top(page) + 20mm",
        bottom = "top(footnotes)"
      },
      runningHead = {
        left = "left(content)",
        right = "right(content)",
        top = "top(page) + 12mm",
        bottom = "top(page) + 18mm"
      },
      footnotes = {
        left = "left(content)",
        right = "right(content)",
        height = "0",
        bottom = "bottom(page) - 18mm"
      },
      folio = {
        left = "left(content)",
        right = "right(content)",
        top = "bottom(page) - 12mm",
        height = "6mm"
      }
    }

    SILE.setCommandDefaults("imprint:font", { size = "6.5pt" })

    -- Hack to avoid SILE bug in print editions
    -- See https://github.com/simoncozens/sile/issues/355
    class:registerCommand("href", function (options, content)
      if class.options.verseindex then
        SILE.call("markverse", options, content)
      end
      SILE.process(content)
    end)

  end

end
