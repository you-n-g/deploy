-- This module provides features for processing the response from LLM.

local Popup = require("nui.popup")
local Layout = require("nui.layout")
local utils = require("simplegpt.utils")
local dialog = require("simplegpt.dialog")

local QAUI = utils.class("QAUI", dialog.BaseDialog)
P(QAUI)

function QAUI:ctor(question)
  self.question = question
end

function QAUI:build()
  local q_pop = Popup({
    border = {
      style = "double",
      text = {
        top = "Question:",
        top_align = "center",
      },
    },
  })

  local a_pop = Popup({
    enter = true,
    border = {
      style = "single",
      text = {
        top = "Answer:",
        top_align = "center",
      },
    },
  })

  local layout = Layout(
    {
      position = "50%",
      size = {
        width = "90%",
        height = "90%",
      },
    },
    Layout.Box({
      Layout.Box(q_pop, { size = "40%" }),
      Layout.Box(a_pop, { size = "60%" }),
    }, { dir = "row" })
  )
  P(self.question)
  vim.api.nvim_buf_set_text(q_pop.bufnr, 0, 0, 0, 0, vim.split(self.question, "\n"))
  layout:mount()
end

local qa = QAUI("Who are you?")
qa:build()
