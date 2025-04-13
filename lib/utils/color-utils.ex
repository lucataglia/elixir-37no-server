defmodule Utils.Colors do
  @underline "\u001b[4m"
  @stop_underline "\u001b[24m"

  def withUnderline(str) do
    "#{@underline}#{str}#{@stop_underline}"
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
