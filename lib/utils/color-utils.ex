defmodule Utils.Colors do
  @moduledoc """
  Utils.Colors
  """

  @underline "\u001b[4m"
  @stop_underline "\u001b[24m"

  def with_underline(str) do
    "#{@underline}#{str}#{@stop_underline}"
  end

  def with_yellow(str) do
    IO.ANSI.format([:yellow, str])
  end

  def with_cyan(str) do
    IO.ANSI.format([:cyan, str])
  end

  def with_green(str) do
    "#{IO.ANSI.format([:green, str])}"
  end

  def with_magenta(str) do
    "#{IO.ANSI.format([:magenta, str])}"
  end
end
