-- ~/.config/nvim/lua/custom/snippets/tex.lua
local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

ls.add_snippets("tex", { -- ← Must say "tex" here, not "latex"
  s("preamble", fmt([[
    \documentclass{{scrartcl}}
    \usepackage{{amsfonts}}
    \usepackage{{amsthm}}
    \usepackage{{amsmath}}
    \newtheorem{{definition}}{{Definition}}
    \newtheorem{{theorem}}{{Theorem}}
    \usepackage[left=0.5cm, right=0.5cm, top=0cm, bottom=0cm]{{geometry}}

    \newcommand{{\startsolution}}{{
      \begin{{tikzpicture}}
      \node[draw, fill=yellow!20, rounded corners, text width=4cm, align=center] at (0,0) {{\textbf{{Solution:}}}};
      \end{{tikzpicture}}
    }}
    \usepackage{{float}}

    \hbadness=10000

    \usepackage{{tikz}}
    \usepackage{{algorithm}}
    \usepackage{{algpseudocode}}

    \title{{ {} }}
    \author{{ {} }}

    \begin{{document}}
    {}
    \end{{document}}
  ]], {
    i(1, "HW - ADS2"),
    i(2, "Ibrahim Qatato"),
    i(0)
  }))
})
