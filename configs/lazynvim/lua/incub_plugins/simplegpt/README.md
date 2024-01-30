


Supported special registers
| key             | meaning                                                     |
| -               | -                                                           |
| content         | the whole file content                                      |
| filetype        | the filetype of the file                                    |
| visual          | the selected lines                                          |
| context[TODO..] | the nearby context of the selected line(10 lines up & down) |

# TODOs

- TODOs
  - Misc
    - [x] Resume last answer.
    - [X] Diff mode
    - [ ] Add shortcuts prompt around the box
    - [ ] Fast copy code
    - [ ] Answering in the background
    - [x] temporary register(without saving to disk)
    - Shotcuts
      - [ ] Directly ask error information (load + do!)
        - [ ] while remain the original information.
  - UI:
    - short cuts
  - Navigation
    - [ ] fast saving and loading(without entering name)
    - [ ] Better Preview of the documents
  - Docs
    - [ ] Normal vim doc.
    - [ ] One picture docs.
  - Opensouce routine
    - [ ] Vim CI

- Bugs
  - [ ] qq will trigger error in answer


# Limitations

It only leverage the `ChatCompletion` API (which is the most powerful and frequently used in the future trend).

