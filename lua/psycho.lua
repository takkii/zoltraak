local query = require("vim.treesitter.query")

local M = {}

local default_config = {
  elixir_ls_debugger = {
    initialize_timeout_sec = 20,
    port = "${port}",
    args = {},
    build_flags = "",
    detached = true,
    cwd = nil,
  }
}

local function load_module(module_name)
  local ok, module = pcall(require, module_name)
  assert(ok, string.format('psycho dependency error: %s not installed', module_name))
  return module
end

local function get_arguments()
  local co = coroutine.running()
  if co then
    return coroutine.create(function()
      local args = {}
      vim.ui.input({ prompt = "Args: " }, function(input)
        args = vim.split(input or "", " ")
      end)
      coroutine.resume(co, args)
    end)
  else
    local args = {}
    vim.ui.input({ prompt = "Args: " }, function(input)
      args = vim.split(input or "", " ")
    end)
    return args
  end
end

local function setup_elixir_adapter(dap)
  dap.adapters.mix_task = function(callback, config)
    local handle
    local stdout = vim.loop.new_pipe(false)
    local pid_or_err
    local elixir_ls_debugger = vim.fn.stdpath("data") .. '/mason/bin/elixir-ls-debugger';
    local waiting = config.waiting or 500
    local args
    local script
    local dap = require('dap')
    local type = 'executable'

    if config.current_line then
      script = config.script .. ':' .. vim.fn.line('.')
    else
      script = config.script
    end

    if config.request == 'launch' then
      args = {}
    else
      -- args = {'--open', '--port', config.port, '-c', '--', config.command, config.script}
    end

    local opts = {
      stdio = {nil, stdout},
      args = args,
      detached = false
    }

    handle, pid_or_err = vim.loop.spawn(elixir_ls_debugger, opts, function(code)
      handle:close()
      if code ~= 0 then
        assert(handle, 'elixir-ls-debugger exited with code: ' .. tostring(code))
        print('elixir-ls-debugger exited with code', code)
      end
    end)

    assert(handle, 'Error running elixir-ls-debugger: ' .. tostring(pid_or_err))

    stdout:read_start(function(err, chunk)
      assert(not err, err)
      if chunk then
        vim.schedule(function()
          require('dap.repl').append(chunk)
        end)
      end
    end)
    -- Deleted, Server Wait Status.
  end
end

local function setup_elixir_debugger_configuration(dap)
  dap.configurations.elixir = {
  {
    type = "mix_task",
    name = "mix test",
    task = "test",
    taskArgs = {"--trace"},
    request = "launch",
    startApps = true, -- for Phoenix projects
    projectDir = "${workspaceFolder}",
    requireFiles = {
      "test/**/test_helper.exs",
      "test/**/*_test.exs"
    }
  },
}

  if configs == nil or configs.dap_configurations == nil then
    return
  end

  for _, config in ipairs(configs.dap_configurations) do
    if config.type == "mix_task" then
      table.insert(dap.configurations.elixir, config)
    end
  end
end

function M.setup(opts)
  local config = vim.tbl_deep_extend("force", default_config, opts or {})
  local dap = load_module("dap")
  setup_elixir_adapter(dap, config)
  setup_elixir_debugger_configuration(dap, config)
end

return M
