defmodule Messages do
  @moduledoc """
  Messages
  """

  defp clear_char, do: "[2J"
  defp ita_flag, do: "\u{1F1EE}\u{1F1F9}"

  def title,
    do:
      IO.ANSI.format([
        :cyan,
        """
        #{clear_char()}
        +----------------------------------------+
        | Tre sette ciapa no (Luca Tagliabue) #{ita_flag()} |
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

  def card_already_used(card), do: "#{card} - You don't have that card\n"

  def type_replay_to_play_again(), do: "Type replay to play again\n"

  def game_ends_message(), do: "The game is over\n"

  def type_replay_to_start_a_new_game(), do: "Type replay to start a new game\n"

  def end_game_invalid_input(), do: "Type replay to continue \n"

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

  def print_table(game_state, name, opts \\ []) do
    piggyback = Keyword.get(opts, :piggyback, "empty")
    stash = Keyword.get(opts, :stash, "")
    behavior = Keyword.get(opts, :behavior, "")

    players = game_state[:players]
    observers = game_state[:observers]
    dealer_index = game_state[:dealer_index]
    used_card_count = game_state[:used_card_count]
    turn_winner = game_state[:turn_winner]
    prev_turn = game_state[:prev_turn]

    # Observer
    notifications_observers = game_state[:notifications][:observers]

    observed_accepted_count =
      Enum.count(notifications_observers, fn el ->
        case el do
          {_, ^name, "accepted"} -> true
          _ -> false
        end
      end)

    observer_notification_msg = NotificationTable.render_observer_notifications_table(notifications_observers, name)
    observed_notification_msg = NotificationTable.render_observed_notifications_table(notifications_observers, name)

    name_of_the_player_that_i_am_observing =
      Enum.find_value(notifications_observers, fn
        {observer, observed, "accepted"} when observer == name -> observed
        _ -> nil
      end)

    obs_count = String.pad_trailing("#{map_size(observers)} (#{observed_accepted_count})", 12)
    # *** End Observer

    end_game = game_state[:end_game]
    replay_names = end_game[:replay_names]
    share_names = end_game[:share_names]

    share =
      if share_names !== [] do
        "\n\n" <>
          Utils.Colors.with_underline("Share") <>
          ":\n\n" <>
          (share_names
           |> Enum.map(fn name ->
             "#{String.pad_trailing(name, 14)} #{Deck.print_card_in_order(players[name][:cards], print_also_used_cards: true, print_also_high_cards_count: true)}"
           end)
           |> Enum.join("\n"))
      else
        ""
      end

    replay =
      if replay_names !== [] do
        "\n\n\n" <>
          Utils.Colors.with_underline("Replay") <>
          ": " <>
          Actors.NewTableManager.Messages.wants_to_replay(replay_names)
      else
        ""
      end

    [me, p1, p2] = reorder_by_name(players, name_of_the_player_that_i_am_observing || name)

    # LEADERBOARD, LEGEND and EXAMPLES
    [{_, first}, {_, second}, {_, third}] = players |> Enum.sort_by(fn {_, %{leaderboard: l}} -> Enum.sum(l) end)
    there_is_a_looser = third[:is_looser]
    winner = if there_is_a_looser, do: first, else: nil

    winner_icon =
      case there_is_a_looser do
        true -> "👑"
        false -> ""
      end

    winner_str_len = if winner_icon == "", do: 19, else: 18

    leaderboardxxxxxxxxxxx = String.pad_trailing(Utils.Colors.with_underline("Leaderboard"), 31)
    first_leaderboardxx = String.pad_trailing("#{first[:name]} #{first[:leaderboard] |> Enum.sum()} #{winner_icon}", winner_str_len)
    second_leaderboardx = String.pad_trailing("#{second[:name]} #{second[:leaderboard] |> Enum.sum()}", 19)
    third_leaderboardxx = String.pad_trailing("#{third[:name]} #{third[:leaderboard] |> Enum.sum()}", 19)

    legendxxxxxxxx = String.pad_trailing(Utils.Colors.with_underline("Legend"), 22)
    heartsxxxxxxxx = String.pad_trailing("#{Deck.heart()} Hearts", 15)
    diamondsxxxxxx = String.pad_trailing("#{Deck.diamond()} Diamonds", 15)
    clubsxxxxxxxxx = String.pad_trailing("#{Deck.clubs()} Clubs", 15)
    spadesxxxxxxxx = String.pad_trailing("#{Deck.spades()} Spades", 15)

    examplexxxxxxx = String.pad_leading(Utils.Colors.with_underline("Example"), 27)
    exheartsxxxxxx = String.pad_leading("7h -> 7 #{Deck.heart()}", 14)
    exdiamondsxxxx = String.pad_leading("jd -> J #{Deck.diamond()}", 14)
    exclubsxxxxxxx = String.pad_leading("ac -> A #{Deck.clubs()}", 14)
    exspadesxxxxxx = String.pad_leading("3s -> 3 #{Deck.spades()}", 14)

    # RECTANGLE
    circle =
      cond do
        there_is_a_looser -> Utils.Colors.with_magenta("\u25CF")
        true -> "\u25CF"
      end

    v =
      cond do
        there_is_a_looser -> Utils.Colors.with_magenta("\u2503")
        true -> "\u2503"
      end

    h =
      cond do
        there_is_a_looser -> Utils.Colors.with_magenta("\u2501")
        true -> "\u2501"
      end

    pretties =
      prev_turn
      |> Enum.sort_by(fn {_, %{ranking: r}} -> r end, :desc)
      |> Enum.map(fn {_, %{pretty: p}} -> p end)
      |> Enum.join(" ")

    infoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx =
      cond do
        turn_winner == p1[:name] ->
          String.pad_trailing("#{Utils.Colors.with_yellow_bright(turn_winner)}: #{pretties}", 89)

        turn_winner == me[:name] ->
          str = "#{Utils.Colors.with_yellow_bright(turn_winner)}: #{pretties}"
          total_len = 89
          str_len = String.length(str)
          total_padding = max(total_len - str_len, 0)
          left_padding = div(total_padding, 2)
          right_padding = total_padding - left_padding

          str
          |> String.pad_leading(str_len + left_padding)
          |> String.pad_trailing(str_len + left_padding + right_padding)

        turn_winner == p2[:name] ->
          String.pad_leading("#{Utils.Colors.with_yellow_bright(turn_winner)}: #{pretties}", 89)

        true ->
          ""
      end

    dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx =
      "#{circle}" <> String.duplicate("#{h}", 77) <> "#{circle}"

    # TURN_WINNER
    a =
      cond do
        p1[:name] == turn_winner ->
          String.pad_trailing("#{IO.ANSI.format([:yellow, :bright, "\u2503"])}", 17)

        p1[:name] != turn_winner ->
          String.pad_trailing(" ", 4)
      end

    b =
      cond do
        p2[:name] == turn_winner ->
          String.pad_leading("#{IO.ANSI.format([:yellow, :bright, "\u2503"])}", 17)

        p2[:name] != turn_winner ->
          String.pad_leading(" ", 4)
      end

    cxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx =
      cond do
        me[:name] == turn_winner ->
          String.duplicate("#{IO.ANSI.format([:yellow, :bright, "\u2501"])}", 73)

        me[:name] != turn_winner ->
          String.duplicate(" ", 73)
      end

    # NAMES

    dealer_name_blueexxxx =
      cond do
        there_is_a_looser ->
          String.pad_trailing("#{IO.ANSI.format([:magenta, :bright, "#{winner[:name]} wins 👑"])}", 36)

        true ->
          String.pad_trailing("", 24)
      end

    p1_lastxxx = if p1[:last], do: String.pad_trailing("#{Utils.Colors.with_yellow_bright(p1[:last][:key])}", 25), else: String.pad_leading("", 13)
    p2_last = if p2[:last], do: String.pad_leading("#{Utils.Colors.with_yellow_bright(p2[:last][:key])}", 24), else: String.pad_leading("", 10)
    me_last = if me[:last], do: String.pad_trailing("#{Utils.Colors.with_yellow_bright(me[:last][:key])}", 23), else: String.pad_leading("", 10)

    p1_namexxxxxxxxxxx =
      (
        {len_offset, name_with_icon} =
          cond do
            winner[:name] == p1[:name] -> {-1, "#{p1[:name]} 👑"}
            p1[:is_stopped] -> {-1, "#{p1[:name]} 🚫"}
            true -> {0, p1[:name]}
          end

        if p1[:index] == dealer_index do
          String.pad_leading("#{IO.ANSI.format([:cyan, name_with_icon])}", 30 + len_offset)
        else
          String.pad_leading(name_with_icon, 21 + len_offset)
        end
      )

    p2_name =
      (
        name_with_icon =
          cond do
            winner[:name] == p2[:name] -> "#{p2[:name]} 👑"
            p2[:is_stopped] -> "#{p2[:name]} 🚫"
            true -> p2[:name]
          end

        if p2[:index] == dealer_index do
          IO.ANSI.format([:cyan, name_with_icon])
        else
          name_with_icon
        end
      )

    me_name =
      (
        name_with_icon =
          cond do
            winner[:name] == me[:name] -> "#{me[:name]} 👑"
            me[:is_stopped] -> "#{me[:name]} 🚫"
            true -> me[:name]
          end

        if me[:index] == dealer_index do
          IO.ANSI.format([:cyan, name_with_icon])
        else
          name_with_icon
        end
      )

    owl_line_one_______ = if behavior != :observer && me[:index] == dealer_index, do: IO.ANSI.format([:cyan, "┌──────────────────┐"]), else: ""
    owl_line_two_______ = if behavior != :observer && me[:index] == dealer_index, do: IO.ANSI.format([:cyan, "│ It's your turn!! │"]), else: ""
    owl_line_three_____ = if behavior != :observer && me[:index] == dealer_index, do: IO.ANSI.format([:cyan, "└──────────────────┘"]), else: ""
    # owl_line_four______ = if behavior != :observer && me[:index] == dealer_index, do: IO.ANSI.format([:cyan, "        \\"]), else: ""
    # owl_line_five______ = if behavior != :observer && me[:index] == dealer_index, do: IO.ANSI.format([:cyan, "         \\"]), else: ""
    # owl_line_six_______ = if behavior != :observer && me[:index] == dealer_index, do: IO.ANSI.format([:cyan, "          ,_,"]), else: ""
    # owl_line_seven_____ = if behavior != :observer && me[:index] == dealer_index, do: IO.ANSI.format([:cyan, "         (O,O)"]), else: ""
    # owl_line_eight_____ = if behavior != :observer && me[:index] == dealer_index, do: IO.ANSI.format([:cyan, "         (   )"]), else: ""
    # owl_line_nine______ = if behavior != :observer && me[:index] == dealer_index, do: IO.ANSI.format([:cyan, "          \" \""]), else: ""

    # CARDS

    my_cards =
      cond do
        name_of_the_player_that_i_am_observing -> Deck.print_card_in_order(me[:cards])
        behavior == :observer -> ""
        true -> Deck.print_card_in_order(me[:cards])
      end

    # STACK
    p1s =
      case length(p1[:stack]) do
        0 ->
          "      "

        _ ->
          "    🃏"
      end

    p2s =
      case length(p2[:stack]) do
        0 ->
          ""

        _ ->
          "🃏"
      end

    mes =
      case length(me[:stack]) do
        0 ->
          ""

        _ ->
          "🃏"
      end

    # CURRENT
    p1_curr =
      case get_in(p1, [:current, :pretty]) do
        "" -> String.pad_trailing("", 10)
        nil -> String.pad_trailing("", 10)
        c -> String.pad_trailing(c, 9)
      end

    p2_curr =
      case get_in(p2, [:current, :pretty]) do
        "" -> String.pad_leading("", 10)
        nil -> String.pad_leading("", 10)
        c -> String.pad_leading(c, 9)
      end

    me_curr =
      case get_in(me, [:current, :pretty]) do
        "" -> String.pad_trailing("", 10)
        nil -> String.pad_trailing("", 10)
        c -> String.pad_trailing(c, 9)
      end

    # END GAME
    end_game_message =
      cond do
        behavior == :observer ->
          replay_names

        used_card_count == Deck.card_count() ->
          if game_state[:there_is_a_looser] do
            "\n\n\n#{IO.ANSI.format([:yellow, Messages.type_replay_to_start_a_new_game()])}"
          else
            "\n\n\n#{IO.ANSI.format([:yellow, Messages.type_replay_to_play_again()])}"
          end

        true ->
          ""
      end

    end_game_label =
      case used_card_count == Deck.card_count() do
        true ->
          String.pad_trailing(Utils.Colors.with_underline("Player"), 24) <>
            String.pad_trailing(Utils.Colors.with_underline("Points"), 22) <>
            Utils.Colors.with_underline("Cards") <>
            "\n\n"

        false ->
          ""
      end

    {p1_end_game_cards, _, _, _} =
      p1[:stack]
      |> Enum.to_list()
      |> Enum.sort_by(fn {_, %{points: p}} -> -p end)
      |> Enum.reduce({"", 0, 0, nil}, fn {_, %{points: p, key: k}}, {acc, count_1, count_034, prev_p} ->
        # Colorize the key
        colored_key =
          case p do
            1 -> Utils.Colors.with_red_bright(k)
            0.34 -> Utils.Colors.with_yellow(k)
            _ -> k
          end

        # Determine if points changed from previous card
        space_after_change = if prev_p != nil and prev_p != p, do: "  ", else: ""

        # Increment counters if points are 1 or 0.34
        count_1 = if p == 1, do: count_1 + 1, else: count_1
        count_034 = if p == 0.34, do: count_034 + 1, else: count_034

        # Add extra space after every 3rd card with points == 1 or 0.34
        space_after_1 = if p == 1 and rem(count_1, 3) == 0, do: "  ", else: ""
        space_after_034 = if p == 0.34 and rem(count_034, 3) == 0, do: "  ", else: ""

        # Combine all spaces
        spaces = space_after_1 <> space_after_034 <> " "

        # Append to accumulator
        {"#{acc}#{space_after_change}#{colored_key}#{spaces}", count_1, count_034, p}
      end)

    {p2_end_game_cards, _, _, _} =
      p2[:stack]
      |> Enum.to_list()
      |> Enum.sort_by(fn {_, %{points: p}} -> -p end)
      |> Enum.reduce({"", 0, 0, nil}, fn {_, %{points: p, key: k}}, {acc, count_1, count_034, prev_p} ->
        # Colorize the key
        colored_key =
          case p do
            1 -> Utils.Colors.with_red_bright(k)
            0.34 -> Utils.Colors.with_yellow(k)
            _ -> k
          end

        # Determine if points changed from previous card
        space_after_change = if prev_p != nil and prev_p != p, do: "  ", else: ""

        # Increment counters if points are 1 or 0.34
        count_1 = if p == 1, do: count_1 + 1, else: count_1
        count_034 = if p == 0.34, do: count_034 + 1, else: count_034

        # Add extra space after every 3rd card with points == 1 or 0.34
        space_after_1 = if p == 1 and rem(count_1, 3) == 0, do: "  ", else: ""
        space_after_034 = if p == 0.34 and rem(count_034, 3) == 0, do: "  ", else: ""

        # Combine all spaces
        spaces = space_after_1 <> space_after_034 <> " "

        # Append to accumulator
        {"#{acc}#{space_after_change}#{colored_key}#{spaces}", count_1, count_034, p}
      end)

    {me_end_game_cards, _, _, _} =
      me[:stack]
      |> Enum.to_list()
      |> Enum.sort_by(fn {_, %{points: p}} -> -p end)
      |> Enum.reduce({"", 0, 0, nil}, fn {_, %{points: p, key: k}}, {acc, count_1, count_034, prev_p} ->
        # Colorize the key
        colored_key =
          case p do
            1 -> Utils.Colors.with_red_bright(k)
            0.34 -> Utils.Colors.with_yellow(k)
            _ -> k
          end

        # Determine if points changed from previous card
        space_after_change = if prev_p != nil and prev_p != p, do: "  ", else: ""

        # Increment counters if points are 1 or 0.34
        count_1 = if p == 1, do: count_1 + 1, else: count_1
        count_034 = if p == 0.34, do: count_034 + 1, else: count_034

        # Add extra space after every 3rd card with points == 1 or 0.34
        space_after_1 = if p == 1 and rem(count_1, 3) == 0, do: "  ", else: ""
        space_after_034 = if p == 0.34 and rem(count_034, 3) == 0, do: "  ", else: ""

        # Combine all spaces
        spaces = space_after_1 <> space_after_034 <> " "

        # Append to accumulator
        {"#{acc}#{space_after_change}#{colored_key}#{spaces}", count_1, count_034, p}
      end)

    {me_end_game, p1_end_game, p2_end_game} =
      cond do
        used_card_count == Deck.card_count() ->
          p1_name =
            cond do
              winner[:name] == p1[:name] -> "👑 #{p1[:name]}"
              winner[:name] && winner[:name] != p1[:name] -> "☹️ #{p1[:name]}"
              p1[:is_stopped] -> "🚫 #{p1[:name]}"
              true -> p1[:name]
            end

          p2_name =
            cond do
              winner[:name] == p2[:name] -> "👑 #{p2[:name]}"
              winner[:name] && winner[:name] != p2[:name] -> "☹️ #{p2[:name]}"
              p2[:is_stopped] -> "🚫 #{p2[:name]}"
              true -> p2[:name]
            end

          me_name =
            cond do
              winner[:name] == me[:name] -> "👑 #{me[:name]}"
              winner[:name] && winner[:name] != me[:name] -> "☹️ #{me[:name]}"
              me[:is_stopped] -> "🚫 #{me[:name]}"
              true -> me[:name]
            end

          {"#{String.pad_trailing(me_name, 14)} #{String.pad_trailing("#{me[:points]}", 12)} #{me_end_game_cards}\n",
           "#{String.pad_trailing(p1_name, 14)} #{String.pad_trailing("#{p1[:points]}", 12)} #{p1_end_game_cards}\n",
           "#{String.pad_trailing(p2_name, 14)} #{String.pad_trailing("#{p2[:points]}", 12)} #{p2_end_game_cards}\n"}

        true ->
          {"", "", ""}
      end

    card_value_recap = "   #{Utils.Colors.with_underline("Card values")}: #{Utils.Colors.with_red_bright("Ace = 1 pt")}, #{Utils.Colors.with_yellow("2/3/face = 1/3 pt")}, others = 0"
    card_hierarchy_recap = "#{Utils.Colors.with_underline("Card hierarchy")}: 3 > 2 > Ace > King > Queen > Jack > 7 > 6 > 5 > 4"

    piggyback_with_leading_new_line =
      if piggyback do
        "\n\n#{piggyback}"
      else
        ""
      end

    """
    #{clear_char()}
    #{title()}

                                      #{card_value_recap}
                                      #{card_hierarchy_recap}


                              #{leaderboardxxxxxxxxxxx}           #{legendxxxxxxxx}               #{examplexxxxxxx}
                              1. #{first_leaderboardxx}           #{heartsxxxxxxxx}               #{exheartsxxxxxx}
                              2. #{second_leaderboardx}           #{diamondsxxxxxx}               #{exdiamondsxxxx}
                              3. #{third_leaderboardxx}           #{clubsxxxxxxxxx}               #{exclubsxxxxxxx}
                                                               #{spadesxxxxxxxx}               #{exspadesxxxxxx}


                              #{infoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}
                              #{dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}
                              #{v}                                 #{dealer_name_blueexxxx}                    #{v}
                              #{v}#{a}                                                                     #{b}#{v}
                              #{v}#{a}                                                                     #{b}#{v}
                              #{v}#{a}                                                                     #{b}#{v}
                              #{v}#{a}                                                                     #{b}#{v}
                              #{v}#{a}                                                                     #{b}#{v}
       #{p1_namexxxxxxxxxxx}  #{v}#{a}  #{p1_lastxxx}       #{p1_curr}     #{p2_curr}          #{p2_last}  #{b}#{v}  #{p2_name} #{p2s}
                      #{p1s}  #{v}#{a}                                                                     #{b}#{v}
                              #{v}#{a}                                 #{me_curr}                          #{b}#{v}
                              #{v}#{a}                                                                     #{b}#{v}
                              #{v}#{a}                                                                     #{b}#{v}
                              #{v}#{a}                                  #{me_last}                         #{b}#{v}
                              #{v}#{a}                                                                     #{b}#{v}
                              #{v}  #{cxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}  #{v}
                              #{dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}

                              #{my_cards}

                              👀 #{obs_count}                  #{me_name} #{mes} #{stash}


                                                              #{owl_line_one_______}
                                                              #{owl_line_two_______}
                                                              #{owl_line_three_____}

    """ <>
      end_game_label <>
      me_end_game <>
      p1_end_game <>
      p2_end_game <>
      share <>
      replay <>
      end_game_message <>
      observed_notification_msg <>
      observer_notification_msg <>
      piggyback_with_leading_new_line
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

defmodule NotificationTable do
  alias TableRex.Table

  def render_observer_notifications_table(notifications_observers, name) do
    # Filter relevant notifications for this observer
    rows =
      notifications_observers
      |> Enum.filter(fn
        {observer, _, _} when observer == name -> true
        _ -> false
      end)
      |> Enum.map(fn
        {_, observed, "pending"} ->
          ["🕣 Pending", "Waiting for observation approval", observed]

        {_, observed, "rejected"} ->
          ["❌ Rejected", "Request to observe the game denied or revoked", observed]

        {_, observed, "accepted"} ->
          ["✅ Accepted", "Request to observe the game accepted", observed]
      end)

    if rows == [] do
      ""
    else
      # Create the table with headers
      "\n\n#{Table.new(rows, ["Status", "Message", "Observed"]) |> Table.put_column_meta(0, align: :center) |> Table.render!()}"
    end
  end

  def render_observed_notifications_table(notifications_observers, name) do
    # Filter relevant notifications for this observed
    rows =
      notifications_observers
      |> Enum.filter(fn
        {_, observed, status} when observed == name and status in ["pending", "accepted"] -> true
        _ -> false
      end)
      |> Enum.map(fn
        {observer, _, "pending"} ->
          ["🕣 Pending", "Someone want to observe your game", observer]

        {observer, _, "accepted"} ->
          ["✅ Accepted", "You accepted to be observed", observer]
      end)

    if rows == [] do
      ""
    else
      # Create the table with headers
      "\n\n#{Table.new(rows, ["Status", "Message", "Observer"]) |> Table.put_column_meta(0, align: :center) |> Table.render!()}"
    end
  end
end
