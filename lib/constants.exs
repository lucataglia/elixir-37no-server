defmodule Constants do
  def clear_char, do: "[2J"

  def ita_flag, do: "\u{1F1EE}\u{1F1F9}"

  def title,
    do:
      IO.ANSI.format([
        :cyan,
        """
        #{clear_char()}
        +----------------------------------------+
        | Tre sette chapa no (Luca Tagliabue) #{ita_flag()} |
        +----------------------------------------+


        """
      ])

  def warning(message),
    do: IO.ANSI.format([:yellow, "#{message}\n"])

  def success(message),
    do: IO.ANSI.format([:green, "#{message}\n"])

  def print_table(new_players_with_cards, name) do
    IO.inspect(reorder_by_name(new_players_with_cards, name))

    "ciao"
  end

  # Private methods
  defp reorder_by_name(game_state, target_name) do
    {matching, rest} = Enum.split_with(game_state, fn %{name: name} -> name == target_name end)
    matching ++ rest
  end
end
