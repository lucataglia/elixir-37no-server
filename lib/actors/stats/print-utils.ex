defmodule Actors.Stats.PrintUtils do
  @moduledoc """
    Stats
  """
  alias Utils.Colors

  # Utils API
  defp visible_length(str) do
    Regex.replace(~r/\e\[[\d;]*m/, str, "")
    |> String.length()
  end

  defp pad_visible(str, width) do
    visible_len = visible_length(str)
    padding = max(width - visible_len, 0)
    str <> String.duplicate(" ", padding)
  end

  def pretty_print_stats(name, stats_map) when is_map(stats_map) do
    rows =
      stats_map
      |> Enum.map(fn {k, v} ->
        {to_string(k)
         |> String.replace("_", " ")
         |> String.capitalize(), to_string(v)}
      end)

    header = {Colors.with_green("Stats"), Colors.with_light_green(name)}

    key_width =
      Enum.map(rows, fn {k, _} -> visible_length(k) end)
      |> Enum.max(fn -> 3 end)
      |> max(visible_length(elem(header, 0)))

    val_width =
      Enum.map(rows, fn {_, v} -> visible_length(v) end)
      |> Enum.max(fn -> 5 end)
      |> max(visible_length(elem(header, 1)))

    format_row = fn {key, val} ->
      "| " <>
        pad_visible(key, key_width) <>
        " | " <>
        pad_visible(val, val_width) <>
        " |"
    end

    lines =
      [
        "+" <> String.duplicate("-", key_width + 2) <> "+" <> String.duplicate("-", val_width + 2) <> "+",
        format_row.(header),
        "+" <> String.duplicate("-", key_width + 2) <> "+" <> String.duplicate("-", val_width + 2) <> "+",
        Enum.map(rows, format_row),
        "+" <> String.duplicate("-", key_width + 2) <> "+" <> String.duplicate("-", val_width + 2) <> "+"
      ]
      |> List.flatten()

    Enum.join(lines, "\n")
  end
end
