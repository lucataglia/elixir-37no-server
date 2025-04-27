defmodule Messages do
  @moduledoc """
  Messages
  """

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

    "\nPlayers: #{players_name}\nWaiting for other #{count} #{player_word}...\n"
  end

  def wait_your_turn(), do: "Wait your turn\n"

  def you_dont_have_that_card(card), do: "You don't have the #{card}\n"

  def unexisting_card(card), do: "#{card} is not a valid card\n"

  def you_have_to_play_the_right_suit(card, right_suit), do: "#{card} - You have to play #{right_suit}\n"

  def type_replay_to_play_again(), do: "Type replay to play again\n"

  def end_game_invalid_input(), do: "Type replay to play again \n"

  def ready_to_replay_invalid_input(), do: "Other players still need to confirm if they want to replay \n"

  def message(message),
    do: "#{message}\n"

  def warning(message),
    do: IO.ANSI.format([:yellow, "#{message}\n"])

  def success(message),
    do: IO.ANSI.format([:light_green, "#{message}\n"])

  def print_summary_table do
    # Helper function to calculate visible length (without ANSI codes)
    visible_length = fn string ->
      string
      # Strip ANSI color codes
      |> String.replace(~r/\e\[[0-9;]*m/, "")
      |> String.length()
    end

    header_aspect = Utils.Colors.with_green("Aspect")
    header_details = Utils.Colors.with_green("Details")

    rows = [
      {header_aspect, header_details},
      {"Players", "3"},
      {"Deck", "39-card Italian regional deck"},
      {"Card hierarchy", "3 > 2 > Ace > King > Queen > Jack > 7 > 6 > 5 > 4"},
      {"Card values", "Ace = 1 pt, 2/3/face = 1/3 pt, others = 0"},
      {"Max points per deal", "11"},
      {"Game ends when", "Any player reaches 21+ points"},
      {"Objective", "Have the LOWEST total score when game ends"},
      {"Victory condition", "Player with least points when any player crosses 21"}
    ]

    # Calculate max widths using visible length (without ANSI codes)
    {max_aspect, max_details} =
      Enum.reduce(rows, {0, 0}, fn {aspect, details}, {max_a, max_d} ->
        {
          max(visible_length.(aspect), max_a),
          max(visible_length.(details), max_d)
        }
      end)

    separator = "|#{String.duplicate("-", max_aspect + 2)}|#{String.duplicate("-", max_details + 2)}|"

    table_lines =
      rows
      |> Enum.map(fn {aspect, details} ->
        # Pad using visible length but keep original strings with colors
        aspect_padded = String.pad_trailing(aspect, max_aspect + (String.length(aspect) - visible_length.(aspect)))
        details_padded = String.pad_trailing(details, max_details + (String.length(details) - visible_length.(details)))
        "| #{aspect_padded} | #{details_padded} |"
      end)
      # Add separators before first row, between rows, and after last row
      |> then(fn lines -> [separator] ++ Enum.intersperse(lines, separator) ++ [separator] end)

    Enum.join(table_lines, "\n")
  end

  def recap_sentence do
    goal = "In each deal, your goal is to score #{Utils.Colors.with_underline("as few points as possible")}."

    warning =
      "However, you must score #{Utils.Colors.with_underline("at least 1 point per deal")}.\n" <>
        "Failing to do so results in a penalty of #{Utils.Colors.with_yellow_and_underline("11 points added to your total score")}."

    [goal, "\n", warning, IO.ANSI.reset()] |> IO.iodata_to_binary()
  end

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

          Utils.String.ensure_min_length("#{dealer_name} you're up 🦉", 19, " ", :right)

        true ->
          Utils.String.ensure_min_length("Game ended 🦉", 19, " ", :right)
      end

    p1_name =
      if p1[:index] == dealer_index do
        Utils.String.ensure_min_length(
          "#{IO.ANSI.format([:cyan, p1[:name]])}",
          19,
          " ",
          :left
        )
      else
        Utils.String.ensure_min_length(p1[:name], 10, " ", :left)
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
    p1_cards = length(p1[:cards] |> Enum.to_list() |> Enum.filter(fn {_, %{used: u}} -> !u end)) |> to_string |> Utils.String.ensure_min_length(2, :left)
    p2_cards = length(p2[:cards] |> Enum.to_list() |> Enum.filter(fn {_, %{used: u}} -> !u end)) |> to_string |> Utils.String.ensure_min_length(2, :right)
    me_cards = length(me[:cards] |> Enum.to_list() |> Enum.filter(fn {_, %{used: u}} -> !u end)) |> to_string |> Utils.String.ensure_min_length(2, :right)

    {_, my_cards} =
      me[:cards]
      |> Enum.to_list()
      |> Enum.sort_by(fn {_, %{sort_id: s}} -> s end)
      |> Enum.map(fn {_, card} ->
        new_p =
          case card do
            %{used: true} -> Utils.String.ensure_min_length("", 2, :right)
            %{used: false, pretty: p} -> Utils.String.ensure_min_length(p, 2, :right)
            %{pretty: p} -> Utils.String.ensure_min_length(p, 2, :right)
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
              Utils.String.ensure_min_length("#{IO.ANSI.format([:light_green, "0"])}", 10, :right)

            p1[:name] != turn_winner ->
              "0"
          end

        _ ->
          cond do
            p1[:name] == turn_winner ->
              Utils.String.ensure_min_length("#{IO.ANSI.format([:light_green, "?"])}", 10, :right)

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
        "" -> Utils.String.ensure_min_length("", 10, :right)
        nil -> Utils.String.ensure_min_length("", 10, :right)
        c -> Utils.String.ensure_min_length(c, 9, :right)
      end

    p2_curr =
      case get_in(p2, [:current, :pretty]) do
        "" -> Utils.String.ensure_min_length("", 10, :left)
        nil -> Utils.String.ensure_min_length("", 10, :left)
        c -> Utils.String.ensure_min_length(c, 9, :left)
      end

    me_curr =
      case get_in(me, [:current, :pretty]) do
        "" -> Utils.String.ensure_min_length("", 10, :right)
        nil -> Utils.String.ensure_min_length("", 10, :right)
        c -> Utils.String.ensure_min_length(c, 9, :right)
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
    there_is_a_looser = third[:is_looser]

    winner_icon =
      case there_is_a_looser do
        true -> "👑"
        false -> ""
      end

    leaderboardxxxxxxxxxxx = Utils.String.ensure_min_length(Utils.Colors.with_underline("Leaderboard"), 31, :right)
    first_leaderboardxx = Utils.String.ensure_min_length("#{first[:name]} #{first[:leaderboard] |> Enum.sum()} #{winner_icon}", 19, :right)
    second_leaderboardx = Utils.String.ensure_min_length("#{second[:name]} #{second[:leaderboard] |> Enum.sum()}", 19, :right)
    third_leaderboardxx = Utils.String.ensure_min_length("#{third[:name]} #{third[:leaderboard] |> Enum.sum()}", 19, :right)

    legendxxxxxxxx = Utils.String.ensure_min_length(Utils.Colors.with_underline("Legend"), 22, :right)
    heartsxxxxxxxx = Utils.String.ensure_min_length("Hearts 🔴️", 15, :right)
    diamondsxxxxxx = Utils.String.ensure_min_length("Diamonds 🔵", 15, :right)
    clubsxxxxxxxxx = Utils.String.ensure_min_length("Clubs 🟢", 15, :right)
    spadesxxxxxxxx = Utils.String.ensure_min_length("Spades ⚫️", 15, :right)

    examplexxxxxxx = Utils.String.ensure_min_length(Utils.Colors.with_underline("Example"), 27, :left)
    exheartsxxxxxx = Utils.String.ensure_min_length("7h -> 7 🔴️", 14, :left)
    exdiamondsxxxx = Utils.String.ensure_min_length("jd -> J 🔵", 14, :left)
    exclubsxxxxxxx = Utils.String.ensure_min_length("ac -> A 🟢", 14, :left)
    exspadesxxxxxx = Utils.String.ensure_min_length("3s -> 3 ⚫️", 14, :left)

    """
    #{clear_char()}
    #{title()}

                              #{leaderboardxxxxxxxxxxx}           #{legendxxxxxxxx}               #{examplexxxxxxx}
                              1. #{first_leaderboardxx}           #{heartsxxxxxxxx}               #{exheartsxxxxxx}
                              2. #{second_leaderboardx}           #{diamondsxxxxxx}               #{exdiamondsxxxx}
                              3. #{third_leaderboardxx}           #{clubsxxxxxxxxx}               #{exclubsxxxxxxx}
                                                               #{spadesxxxxxxxx}               #{exspadesxxxxxx}


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
