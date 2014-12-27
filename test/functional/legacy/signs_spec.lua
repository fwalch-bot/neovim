-- Tests for signs

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('signs', function()
  setup(clear)

  it('is working', function()
    execute('so small.vim')
    execute('if !has("signs")')
    execute('  e! test.ok')
    execute('  wq! test.out')
    execute('endif')

    execute('sign define JumpSign text=x')
    execute([[exe 'sign place 42 line=2 name=JumpSign buffer=' . bufnr('')]])
    -- Split the window to the bottom to verify :sign-jump will stay in the current.
    -- Window if the buffer is displayed there.
    execute('bot split')
    execute([[exe 'sign jump 42 buffer=' . bufnr('')]])
    execute([[call append(line('$'), winnr())]])
    execute('$-1,$w! test.out')
    execute('qa!')

    -- Assert buffer contents.
    expect([[
      
      2]])
  end)
end)
