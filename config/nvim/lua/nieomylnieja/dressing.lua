local is_loaded, dressing = pcall(require, "dressing")
if not is_loaded then
  return
end

-- We're fine with the defaults here.
dressing.setup()
