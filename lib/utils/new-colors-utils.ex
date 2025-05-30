defmodule Utils.NewColors do
  @moduledoc """
  Utils.Colors — helper functions for ANSI color and text styling.
  """

  @underline "\u001b[4m"
  @stop_underline "\u001b[24m"
  @bold "\u001b[1m"
  @stop_bold "\u001b[22m"
  @reversed "\u001b[7m"
  @stop_reversed "\u001b[27m"

  # Text styles

  def with_underline(str), do: "#{@underline}#{str}#{@stop_underline}"
  def with_bold(str), do: "#{@bold}#{str}#{@stop_bold}"
  def with_reversed(str), do: "#{@reversed}#{str}#{@stop_reversed}"

  # Foreground colors

  def with_black(str), do: IO.ANSI.format([:black, str]) |> IO.iodata_to_binary()
  def with_red(str), do: IO.ANSI.format([:red, str]) |> IO.iodata_to_binary()
  def with_green(str), do: IO.ANSI.format([:green, str]) |> IO.iodata_to_binary()
  def with_yellow(str), do: IO.ANSI.format([:yellow, str]) |> IO.iodata_to_binary()
  def with_blue(str), do: IO.ANSI.format([:blue, str]) |> IO.iodata_to_binary()
  def with_magenta(str), do: IO.ANSI.format([:magenta, str]) |> IO.iodata_to_binary()
  def with_cyan(str), do: IO.ANSI.format([:cyan, str]) |> IO.iodata_to_binary()
  def with_white(str), do: IO.ANSI.format([:white, str]) |> IO.iodata_to_binary()

  # Bright foreground colors

  def with_bright_black(str), do: IO.ANSI.format([:bright_black, str]) |> IO.iodata_to_binary()
  def with_bright_red(str), do: IO.ANSI.format([:bright_red, str]) |> IO.iodata_to_binary()
  def with_bright_green(str), do: IO.ANSI.format([:bright_green, str]) |> IO.iodata_to_binary()
  def with_bright_yellow(str), do: IO.ANSI.format([:bright_yellow, str]) |> IO.iodata_to_binary()
  def with_bright_blue(str), do: IO.ANSI.format([:bright_blue, str]) |> IO.iodata_to_binary()
  def with_bright_magenta(str), do: IO.ANSI.format([:bright_magenta, str]) |> IO.iodata_to_binary()
  def with_bright_cyan(str), do: IO.ANSI.format([:bright_cyan, str]) |> IO.iodata_to_binary()
  def with_bright_white(str), do: IO.ANSI.format([:bright_white, str]) |> IO.iodata_to_binary()

  # Background colors

  def with_bg_black(str), do: IO.ANSI.format([:black_background, str]) |> IO.iodata_to_binary()
  def with_bg_red(str), do: IO.ANSI.format([:red_background, str]) |> IO.iodata_to_binary()
  def with_bg_green(str), do: IO.ANSI.format([:green_background, str]) |> IO.iodata_to_binary()
  def with_bg_yellow(str), do: IO.ANSI.format([:yellow_background, str]) |> IO.iodata_to_binary()
  def with_bg_blue(str), do: IO.ANSI.format([:blue_background, str]) |> IO.iodata_to_binary()
  def with_bg_magenta(str), do: IO.ANSI.format([:magenta_background, str]) |> IO.iodata_to_binary()
  def with_bg_cyan(str), do: IO.ANSI.format([:cyan_background, str]) |> IO.iodata_to_binary()
  def with_bg_white(str), do: IO.ANSI.format([:white_background, str]) |> IO.iodata_to_binary()

  # Bright background colors

  def with_bg_bright_black(str), do: IO.ANSI.format([:bright_black_background, str]) |> IO.iodata_to_binary()
  def with_bg_bright_red(str), do: IO.ANSI.format([:bright_red_background, str]) |> IO.iodata_to_binary()
  def with_bg_bright_green(str), do: IO.ANSI.format([:bright_green_background, str]) |> IO.iodata_to_binary()
  def with_bg_bright_yellow(str), do: IO.ANSI.format([:bright_yellow_background, str]) |> IO.iodata_to_binary()
  def with_bg_bright_blue(str), do: IO.ANSI.format([:bright_blue_background, str]) |> IO.iodata_to_binary()
  def with_bg_bright_magenta(str), do: IO.ANSI.format([:bright_magenta_background, str]) |> IO.iodata_to_binary()
  def with_bg_bright_cyan(str), do: IO.ANSI.format([:bright_cyan_background, str]) |> IO.iodata_to_binary()
  def with_bg_bright_white(str), do: IO.ANSI.format([:bright_white_background, str]) |> IO.iodata_to_binary()

  # Combined styles examples

  def with_red_bold(str), do: IO.ANSI.format([:red, :bright, str]) |> IO.iodata_to_binary()
  def with_green_underline(str), do: IO.ANSI.format([:green, :underline, str]) |> IO.iodata_to_binary()
  def with_yellow_bright_underline(str), do: IO.ANSI.format([:yellow, :bright, :underline, str]) |> IO.iodata_to_binary()

  # You can add more combinations as needed
end
