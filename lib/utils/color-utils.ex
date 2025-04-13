defmodule Utils.Colors do
  @underline "\u001b[0004m"
  @nc "\u001b[0;0m"

  def withUnderline(str) do
    "#{@underline}#{str}#{@nc}"
  end

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
