Code.require_file("./utils/string-utils.exs")
Code.require_file("deck.exs")

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

  def name_too_short(), do: "Name must be at least 3 characters\n"
  def name_too_long(), do: "Name must be less than 10 characters\n"
  def name_contains_invalid_chars(), do: "Name must contains only letters or numbers\n"
  def name_already_taken(name), do: "Name #{name} already taken ☹️ please chose another one\n"

  def name_is_valid(name), do: "Greetings #{name} 🙂\n"

  def wait_for_game_start(), do: "Wait for the game to start\n"

  def wait_your_turn(), do: "Wait your turn\n"

  def you_dont_have_that_card(card), do: "You don't have the #{card}\n"

  def unexisting_card(card), do: "#{card} is not a valid card\n"

  def you_have_to_play_the_right_suit(card, right_suit), do: "#{card} - You have to play #{right_suit}\n"

  def type_replay_to_continue(), do: "Type replay to continue\n"

  def message(message),
    do: "#{message}\n"

  def warning(message),
    do: IO.ANSI.format([:yellow, "#{message}\n"])

  def success(message),
    do: IO.ANSI.format([:light_green, "#{message}\n"])

  def print_table(game_state, name, piggyback \\ "") do
    players = game_state[:players]
    dealer_index = game_state[:dealer_index]
    used_card_count = game_state[:used_card_count]
    info = game_state[:info]
    turn_winner = game_state[:turn_winner]
    tfcp = game_state[:turn_first_card][:pretty] || "--"

    circle = "\u25CF"
    v = "\u2503"
    h = "\u2501"

    dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx =
      circle <> String.duplicate(h, 77) <> circle

    [
      me,
      p1,
      p2
    ] = reorder_by_name(players, name)

    # NAMES

    # TODO: put the name in blue so it is equal to the colored name on the edge of the rectangle
    dealer_name_bluee =
      cond do
        used_card_count < Deck.card_count() ->
          {dealer_name, _} =
            players
            |> Enum.to_list()
            |> Enum.find(fn {_, %{index: i}} -> i == dealer_index end)

          StringUtils.ensure_min_length("#{dealer_name} you're up 🦉", 19, " ", :right)

        true ->
          StringUtils.ensure_min_length("Game ended 🦉", 19, " ", :right)
      end

    p1_name =
      if p1[:index] == dealer_index do
        StringUtils.ensure_min_length(
          "#{IO.ANSI.format([:cyan, p1[:name]])}",
          19,
          " ",
          :left
        )
      else
        StringUtils.ensure_min_length(p1[:name], 10, " ", :left)
      end

    p2_name =
      if p2[:index] == dealer_index do
        IO.ANSI.format([:cyan, p2[:name]])
      else
        p2[:name]
      end

    me_name =
      if me[:index] == dealer_index do
        IO.ANSI.format([:cyan, me[:name]])
      else
        me[:name]
      end

    # CARDS
    p1_cards = length(p1[:cards] |> Enum.to_list() |> Enum.filter(fn {_, %{used: u}} -> !u end)) |> to_string |> StringUtils.ensure_min_length(2, :left)
    p2_cards = length(p2[:cards] |> Enum.to_list() |> Enum.filter(fn {_, %{used: u}} -> !u end)) |> to_string |> StringUtils.ensure_min_length(2, :right)
    me_cards = length(me[:cards] |> Enum.to_list() |> Enum.filter(fn {_, %{used: u}} -> !u end)) |> to_string |> StringUtils.ensure_min_length(2, :right)

    {_, my_cards} =
      me[:cards]
      |> Enum.to_list()
      |> Enum.sort_by(fn {_, %{sort_id: s}} -> s end)
      |> Enum.map(fn {_, card} ->
        new_p =
          case card do
            %{used: true} -> StringUtils.ensure_min_length("", 2, :right)
            %{used: false, pretty: p} -> StringUtils.ensure_min_length(p, 2, :right)
            %{pretty: p} -> StringUtils.ensure_min_length(p, 2, :right)
            _ -> "ciao"
          end

        {new_p, card[:suit]}
      end)
      |> Enum.reduce(
        {"hearts", ""},
        fn {p, s}, {prev, acc} ->
          if s == prev do
            {s, "#{acc}#{p} "}
          else
            {s, "#{acc}  ⏺  #{p} "}
          end
        end
      )

    # STACK
    if p1[:name] == turn_winner do
    else
      me[:name]
    end

    p1_stack =
      case length(p1[:stack]) do
        0 ->
          cond do
            p1[:name] == turn_winner ->
              StringUtils.ensure_min_length("#{IO.ANSI.format([:light_green, "0"])}", 10, :right)

            p1[:name] != turn_winner ->
              "0"
          end

        _ ->
          cond do
            p1[:name] == turn_winner ->
              StringUtils.ensure_min_length("#{IO.ANSI.format([:light_green, "?"])}", 10, :right)

            p1[:name] != turn_winner ->
              "?"
          end
      end

    p2_stack =
      case length(p2[:stack]) do
        0 ->
          cond do
            p2[:name] == turn_winner ->
              "#{IO.ANSI.format([:light_green, "0"])}"

            p2[:name] != turn_winner ->
              "0"
          end

        _ ->
          cond do
            p2[:name] == turn_winner ->
              "#{IO.ANSI.format([:light_green, "?"])}"

            p2[:name] != turn_winner ->
              "?"
          end
      end

    me_stack =
      case length(me[:stack]) do
        0 ->
          cond do
            me[:name] == turn_winner ->
              "#{IO.ANSI.format([:light_green, "0"])}"

            me[:name] != turn_winner ->
              "0"
          end

        _ ->
          cond do
            me[:name] == turn_winner ->
              "#{IO.ANSI.format([:light_green, "?"])}"

            me[:name] != turn_winner ->
              "?"
          end
      end

    # P1 CARDS AND STACK
    p1_cards_and_stack = "                #{p1_cards}  #{p1_stack}"

    # CURRENT
    p1_curr =
      case get_in(p1, [:current, :pretty]) do
        "" -> StringUtils.ensure_min_length("", 10, :right)
        nil -> StringUtils.ensure_min_length("", 10, :right)
        c -> StringUtils.ensure_min_length(c, 9, :right)
      end

    p2_curr =
      case get_in(p2, [:current, :pretty]) do
        "" -> StringUtils.ensure_min_length("", 10, :left)
        nil -> StringUtils.ensure_min_length("", 10, :left)
        c -> StringUtils.ensure_min_length(c, 9, :left)
      end

    me_curr =
      case get_in(me, [:current, :pretty]) do
        "" -> StringUtils.ensure_min_length("", 10, :right)
        nil -> StringUtils.ensure_min_length("", 10, :right)
        c -> StringUtils.ensure_min_length(c, 9, :right)
      end

    # END GAME
    p1_end_game_cards =
      p1[:stack]
      |> Enum.to_list()
      |> Enum.sort_by(fn {_, %{sort_id: s}} -> s end)
      |> Enum.map(fn {_, %{points: p, pretty: pr}} ->
        case p do
          1 -> "#{underline()}#{pr}#{nc()}"
          0.34 -> "#{underline()}#{pr}#{nc()}"
          _ -> pr
        end
      end)
      |> Enum.join("  ")

    p2_end_game_cards =
      p2[:stack]
      |> Enum.to_list()
      |> Enum.sort_by(fn {_, %{sort_id: s}} -> s end)
      |> Enum.map(fn {_, %{points: p, pretty: pr}} ->
        case p do
          1 -> "#{underline()}#{pr}#{nc()}"
          0.34 -> "#{underline()}#{pr}#{nc()}"
          _ -> pr
        end
      end)
      |> Enum.join(" ")

    me_end_game_cards =
      me[:stack]
      |> Enum.to_list()
      |> Enum.sort_by(fn {_, %{sort_id: s}} -> s end)
      |> Enum.map(fn {_, %{points: p, pretty: pr}} ->
        case p do
          1 -> "#{underline()}#{pr}#{nc()}"
          0.34 -> "#{underline()}#{pr}#{nc()}"
          _ -> pr
        end
      end)
      |> Enum.join(" ")

    {p1_end_game, p2_end_game, me_end_game} =
      cond do
        used_card_count == Deck.card_count() ->
          {"#{p1[:name]} (#{p1[:points]}):  #{p1_end_game_cards}", "#{p2[:name]} (#{p2[:points]}):  #{p2_end_game_cards}", "#{me[:name]} (#{me[:points]}):  #{me_end_game_cards}"}

        true ->
          {"", "", ""}
      end

    end_game_label =
      case used_card_count == Deck.card_count() do
        true -> "End game"
        false -> ""
      end

    # LEADERBOARD
    [{_, first}, {_, second}, {_, third}] = players |> Enum.sort_by(fn {_, %{leaderboard: l}} -> Enum.sum(l) end)
    IO.inspect(first[:leaderboard])
    first_leaderboard = "#{first[:name]} #{first[:leaderboard] |> Enum.sum()}"
    second_leaderboard = "#{second[:name]} #{second[:leaderboard] |> Enum.sum()}"
    third_leaderboard = "#{third[:name]} #{third[:leaderboard] |> Enum.sum()}"

    """
    #{clear_char()}
    #{title()}

                              Leaderboard
                              1. #{first_leaderboard}
                              2. #{second_leaderboard}
                              3. #{third_leaderboard}


      
                              First: #{tfcp}                       #{info}
                              #{dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}
                              #{v}                               #{dealer_name_bluee}                          #{v}
                              #{v}                                                                             #{v}
                              #{v}                                                                             #{v}
                  #{p1_name}  #{v}     #{p1_curr}                                               #{p2_curr}     #{v}  #{p2_name}
       #{p1_cards_and_stack}  #{v}                                                                             #{v}  #{p2_cards}  #{p2_stack}
                              #{v}                                                                             #{v}
                              #{v}                                                                             #{v}
                              #{v}                                     #{me_curr}                              #{v}
                              #{v}                                                                             #{v}
                              #{dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}

                              #{my_cards}

                                                                   #{me_name}
                                                                   #{me_cards}  #{me_stack}



                              #{end_game_label}
                              #{me_end_game}
                              #{p1_end_game}
                              #{p2_end_game}

    #{piggyback}
    """
  end

  # Private methods
  defp reorder_by_name(players, target_name) do
    {head, tail} =
      players
      |> Enum.to_list()
      |> Enum.sort_by(fn {_, %{index: i}} -> i end)
      |> Enum.map(fn {_, p} -> p end)
      |> Enum.split_while(fn %{name: name} -> name != target_name end)

    tail ++ head
  end
end

# Enum.split_with(game_state, fn %{name: name} -> name == "mario" end)
# game_state = [%{name: "jeff"}, %{name: "mario"}, %{name: "ale"}]
