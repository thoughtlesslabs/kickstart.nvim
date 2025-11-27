-- lua/custom/plugins/autoread_diff.lua
return {
  {
    -- Just a carrier so Lazy runs our config on start
    'nvim-lua/plenary.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      -- 1) Auto-check for external edits (Nextcloud, phone, etc.)
      vim.opt.autoread = true

      local grp = vim.api.nvim_create_augroup('AutoReadChecktime', { clear = true })
      vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
        group = grp,
        callback = function()
          if vim.bo.buftype == '' then
            pcall(vim.cmd.checktime)
          end
        end,
      })

      -- Notify when a file was reloaded from disk
      vim.api.nvim_create_autocmd('FileChangedShellPost', {
        group = grp,
        callback = function(ev)
          vim.notify(('Reloaded on-disk changes for: %s'):format(ev.file or vim.fn.expand '%'), vim.log.levels.INFO, { title = 'autoread' })
        end,
      })

      -- 2) Nicer diffs
      vim.opt.diffopt:append { 'iwhite', 'indent-heuristic', 'algorithm:patience' }

      -- 3) :DiffDisk -> diff current buffer vs the on-disk file
      vim.api.nvim_create_user_command('DiffDisk', function()
        local fname = vim.api.nvim_buf_get_name(0)
        if fname == '' then
          vim.notify('No file name for current buffer', vim.log.levels.WARN, { title = 'DiffDisk' })
          return
        end
        -- open scratch with disk version
        vim.cmd 'vert new'
        local scratch = vim.api.nvim_get_current_buf()
        vim.bo[scratch].buftype = 'nofile'
        vim.bo[scratch].bufhidden = 'wipe'
        vim.bo[scratch].swapfile = false
        vim.bo[scratch].modifiable = true

        -- force re-read from disk
        vim.cmd('silent 0read ++edit ' .. vim.fn.fnameescape(fname))
        vim.cmd 'silent 1delete _' -- remove leading empty line from :read
        vim.api.nvim_buf_set_name(scratch, '[DISK] ' .. vim.fn.fnamemodify(fname, ':t'))

        -- enable diff on both windows
        vim.cmd 'diffthis'
        vim.cmd 'wincmd p'
        vim.cmd 'diffthis'

        vim.notify('Diff opened. ]c/[c jump hunks, do to take from disk, dp to send to disk view.', vim.log.levels.INFO, { title = 'DiffDisk' })
      end, { desc = 'Diff current buffer against the on-disk file' })

      -- 4) If disk changed while you also have unsaved edits, offer a diff
      vim.api.nvim_create_autocmd('FileChangedShell', {
        group = grp,
        callback = function()
          vim.schedule(function()
            local choice = vim.fn.confirm('File changed on disk. Open a diff to merge?', '&Yes\n&No', 1)
            if choice == 1 then
              vim.cmd 'DiffDisk'
            end
          end)
        end,
      })

      -- Optional keymap
      vim.keymap.set('n', '<leader>ud', '<cmd>DiffDisk<CR>', { desc = 'Diff vs on-disk file' })
    end,
  },
}
