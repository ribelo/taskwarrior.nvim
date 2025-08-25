return function(msg, level, opts)
  vim.schedule(function()
    vim.notify(msg, level, opts)
  end)
end
