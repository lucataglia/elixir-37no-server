defmodule Utils.Colors do
  def withYellow(str) do
    IO.ANSI.format([:yellow, str])
  end

  def withCyan(str) do
    IO.ANSI.format([:cyan, str])
  end

  def withGreen(str) do
    "#{IO.ANSI.format([:green, str])}"
  end

  def withMagenta(str) do
    "#{IO.ANSI.format([:magenta, str])}"
  end
end
