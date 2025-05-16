defmodule Actors.Persistence.Stats.PrintUtils do
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
    # Define the keys in the order you want to print
    keys_order = ["played", "won", "avg", "last_game_desc"]

    # Build rows in order, filtering keys that exist
    rows =
      keys_order
      |> Enum.filter(&Map.has_key?(stats_map, &1))
      |> Enum.map(fn key ->
        value = Map.get(stats_map, key)

        formatted_key =
          key
          |> to_string()
          |> String.replace("_", " ")
          |> String.capitalize()

        {formatted_key, to_string(value)}
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

    border = "+" <> String.duplicate("-", key_width + 2) <> "+" <> String.duplicate("-", val_width + 2) <> "+"

    # Split rows into two parts: before and including last_game_desc
    {main_rows, last_desc_rows} = Enum.split(rows, 3)

    # Separator line matching the width of the table
    separator = "|" <> String.duplicate("-", key_width + 2) <> "|" <> String.duplicate("-", val_width + 2) <> "|"

    lines =
      [
        border,
        format_row.(header),
        border,
        Enum.map(main_rows, format_row),
        # <-- separator before last_game_desc
        separator,
        Enum.map(last_desc_rows, format_row),
        border
      ]
      |> List.flatten()

    Enum.join(lines, "\n")
  end
end
