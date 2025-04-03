Code.require_file("./utils/string-utils.exs")

defmodule Messages do
  defp clear_char, do: "[2J"
  defp underline, do: "\u001b[0004m"
  defp nc, do: "\u001b[0;0m"

  defp ita_flag, do: "\u{1F1EE}\u{1F1F9}"

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

  def new_player_arrived(players_name, count) do
    player_word = if count == 1, do: "player", else: "players"

    "Players: #{players_name}\nWaiting for other #{count} #{player_word}...\n"
  end

  def name_already_taken(name), do: "Name #{name} already taken, plase chose another one\n"

  def wait_for_game_start(), do: "Wait for the game to start\n"

  def wait_your_turn(), do: "Wait your turn\n"

  def you_dont_have_that_card(card), do: "You don't have the #{card}\n"

  def unexisting_card(card), do: "#{card} is not a valid card\n"

  def you_have_to_play_the_right_suit(card, right_suit), do: "#{card} - You have to play #{right_suit}\n"

  def message(message),
    do: "#{message}\n"

  def warning(message),
    do: IO.ANSI.format([:yellow, "#{message}\n"])

  def success(message),
    do: IO.ANSI.format([:light_green, "#{message}\n"])

  def print_table(game_state, name, piggyback \\ "") do
    players = game_state[:players]
    turn_first_card_pretty = game_state[:turn_first_card][:pretty]

    circle = "\u25CF"
    right = "\u2571"
    left = "\u2572"
    v = "\u2503"

    dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx =
      circle <> String.duplicate("\u2501", 60) <> circle

    [
      me,
      p1,
      p2
    ] = reorder_by_name(players, name)

    # NAMES
    p1_name =
      if p1[:is_dealer] == true do
        StringUtils.ensure_min_length(
          "       #{IO.ANSI.format([:cyan, p1[:name]])}",
          10,
          " ",
          :left
        )
      else
        StringUtils.ensure_min_length(p1[:name], 10, " ", :left)
      end

    p2_name =
      if p2[:is_dealer] == true do
        IO.ANSI.format([:cyan, p2[:name]])
      else
        p2[:name]
      end

    me_name =
      if me[:is_dealer] == true do
        IO.ANSI.format([:cyan, me[:name]])
      else
        p2[:name]
      end

    # CARDS
    p1_cards = StringUtils.ensure_min_length("#{length(Enum.to_list(p1[:cards]))}", 11, :left)
    p2_cards = length(Enum.to_list(p2[:cards]))

    {_, my_cards} =
      me[:cards]
      |> Enum.to_list()
      |> Enum.map(fn {_, %{pretty: p, suit: s}} -> {p, s} end)
      |> Enum.reduce(
        {"hearts", ""},
        fn {p, s}, {prev, acc} ->
          if s == prev do
            {s, "#{acc}#{p} "}
          else
            {s, "#{acc}    #{p} "}
          end
        end
      )

    # STACK
    p1_stack =
      if length(p1[:stack]) == 0 do
        StringUtils.ensure_min_length("0", 11, :left)
      else
        StringUtils.ensure_min_length("?", 11, :left)
      end

    p2_stack =
      if length(p2[:stack]) == 0 do
        "0"
      else
        "?"
      end

    me_stack =
      if length(me[:stack]) == 0 do
        "0"
      else
        "?"
      end

    # CURRENT
    p1_curr = StringUtils.ensure_min_length(p1[:current], 10, :left)
    p2_curr = StringUtils.ensure_min_length(p2[:current], 10, :left)
    me_curr = StringUtils.ensure_min_length(me[:current], 10, :left)

    """
    #{clear_char()}
                                                #{turn_first_card_pretty}
                    #{dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}
                    #{v}                                                            #{v}
        #{p1_name}  #{v}   #{p1_curr}                                  #{p2_curr}   #{v}  #{p2_name}
       #{p1_cards}  #{v}                                                            #{v}  #{p2_cards}
       #{p1_stack}  #{v}                        #{me_curr}                          #{v}  #{p2_stack}
                    #{v}                                                            #{v}
                    #{dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}

                    #{my_cards}

                                                #{me_name} #{me_stack}


    #{piggyback}
    """
  end

  # Private methods
  defp reorder_by_name(players, target_name) do
    {head, tail} =
      players
      |> Enum.to_list()
      |> Enum.map(fn {_, p} -> p end)
      |> Enum.split_while(fn %{name: name} -> name != target_name end)

    tail ++ head
  end
end

# Enum.split_with(game_state, fn %{name: name} -> name == "mario" end)
# game_state = [%{name: "jeff"}, %{name: "mario"}, %{name: "ale"}]
