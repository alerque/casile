return function (class)

  class.options.papersize = "105mm x 148mm"

  if class._name == "cabook" then

    class.defaultFrameset = {
      content = {
        left = "left(page) + 12mm",
        right = "right(page) - 12mm",
        top = "top(page) + 12mm",
        bottom = "bottom(page) - 12mm"
      }
    }

    class:registerPostinit(function (_)
      SILE.setCommandDefaults("imprint:font", { size = "6.5pt" })
    end)

  end

end
