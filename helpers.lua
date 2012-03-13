
uppercaseIndexTag = newtag()

settagmethod(uppercaseIndexTag, "settable", function (t, i, v)
  rawset(t, strupper(i), v)
end)
settagmethod(uppercaseIndexTag, "gettable", function (t, i)
  return rawget(t, strupper(i))
end)


