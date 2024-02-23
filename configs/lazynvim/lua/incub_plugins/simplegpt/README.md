



# TLDR(Too Long Didn't Read)


# Features


Supported special registers
| key             | meaning                                                     |
| -               | -                                                           |
| content         | the whole file content                                      |
| filetype        | the filetype of the file                                    |
| visual          | the selected lines                                          |
| context[TODO..] | the nearby context of the selected line(10 lines up & down) |

```lua
-- Layzynvim
{
  "you-n-g/simplegpt.git",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "jackMort/ChatGPT.nvim",  -- You should configure your ChatGPT make sure it works.
  },
  config=true,
}
```
# Shutcuts
- Dialog shortcuts:
  - `{"q", "<C-c>", "<esc>"}`: exit the dialog;
  - [ ] Copy code in backquotes;
- normal shortcuts:
  - ...

# TODOs

- TODOs
  - Misc
    - [x] Resume last answer.
    - [X] Diff mode
    - [ ] Fast copy code
    - [ ] Answering in the background
    - [x] temporary register(without saving to disk)
    - Shotcuts
      - [ ] Telescope to run shortcuts.
      - [ ] Directly ask error information (load + do!)
        - [ ] while remain the original information.
  - Targets:
    - Run from targets;
      - Dialog targets ==>  Supporting edit in place.
    - Followup actions;
      - [ ] Replace the text
      - [ ] Append the text
  - UI:
    - short cuts
    - [ ] Help function: You can press `?` to see the help menu for shortcuts.
      - Alternative implementation: [ ] Add shortcuts prompt around the box
  - Navigation
    - [ ] fast saving and loading(without entering name)
      - [ ] remembering the filename in the background.
    - [x] Better Preview of the documents
  - Docs: try panvimdoc 
    - [ ] Normal vim doc(generating from README.md).
    - [ ] One picture docs.
  - Open source routine
    - [ ] Vim CI

- Bugs
  - [ ] qq will trigger error in answer


# Limitations

It only leverage the `ChatCompletion` API (which is the most powerful and frequently used in the future trend).

