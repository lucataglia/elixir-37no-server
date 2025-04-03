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

  def message(message),
    do: "#{message}\n"

  def warning(message),
    do: IO.ANSI.format([:yellow, "#{message}\n"])

  def success(message),
    do: IO.ANSI.format([:light_green, "#{message}\n"])

  def print_table(game_state, name, piggyback \\ "") do
    players = game_state[:players]
    dealer_index = game_state[:dealer_index]
    info = game_state[:info]
    turn_winner = game_state[:turn_winner]
    turn_first_card_pretty = game_state[:turn_first_card][:pretty] || "--"

    circle = "\u25CF"
    right = "\u2571"
    left = "\u2572"
    v = "\u2503"

    dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx =
      circle <> String.duplicate("\u2501", 65) <> circle

    [
      me,
      p1,
      p2
    ] = reorder_by_name(players, name)

    # NAMES
    IO.puts("p1: #{p1[:index]} p2: #{p2[:index]} me: #{me[:index]} dealer_index: #{dealer_index}}")

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
    p1_cards = StringUtils.ensure_min_length("#{length(Enum.to_list(p1[:cards]))}", 11, :left)
    p2_cards = length(Enum.to_list(p2[:cards]))

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
              StringUtils.ensure_min_length("#{IO.ANSI.format([:light_green, "0"])}", 20, :left)

            p1[:name] != turn_winner ->
              StringUtils.ensure_min_length("0", 11, :left)
          end

        _ ->
          cond do
            p1[:name] == turn_winner ->
              StringUtils.ensure_min_length("#{IO.ANSI.format([:light_green, "?"])}", 20, :left)

            p1[:name] != turn_winner ->
              StringUtils.ensure_min_length("?", 11, :left)
          end
      end

    p2_stack =
      case length(p2[:stack]) do
        0 ->
          cond do
            p2[:name] == turn_winner ->
              StringUtils.ensure_min_length("#{IO.ANSI.format([:light_green, "0"])}", 11, :right)

            p2[:name] != turn_winner ->
              StringUtils.ensure_min_length("0", 11, :right)
          end

        _ ->
          cond do
            p2[:name] == turn_winner ->
              StringUtils.ensure_min_length("#{IO.ANSI.format([:light_green, "?"])}", 11, :right)

            p2[:name] != turn_winner ->
              StringUtils.ensure_min_length("?", 11, :right)
          end
      end

    me_stack =
      case length(me[:stack]) do
        0 ->
          cond do
            me[:name] == turn_winner ->
              StringUtils.ensure_min_length("#{IO.ANSI.format([:light_green, "0"])}", 11, :right)

            me[:name] != turn_winner ->
              StringUtils.ensure_min_length("0", 11, :right)
          end

        _ ->
          cond do
            me[:name] == turn_winner ->
              StringUtils.ensure_min_length("#{IO.ANSI.format([:light_green, "?"])}", 11, :right)

            me[:name] != turn_winner ->
              StringUtils.ensure_min_length("?", 11, :right)
          end
      end

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

    """
    #{clear_char()}
    #{title()}

                    First: #{turn_first_card_pretty}
                    #{info}
                    #{dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}
                    #{v}                                                                 #{v}
                    #{v}                                                                 #{v}
                    #{v}                                                                 #{v}
        #{p1_name}  #{v}     #{p1_curr}                                   #{p2_curr}     #{v}  #{p2_name}
       #{p1_cards}  #{v}                                                                 #{v}  #{p2_cards}
       #{p1_stack}  #{v}                                                                 #{v}  #{p2_stack}
                    #{v}                                                                 #{v}
                    #{v}                              #{me_curr}                         #{v}
                    #{v}                                                                 #{v}
                    #{dividerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx}

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
      |> Enum.sort_by(fn {_, %{index: i}} -> i end)
      |> Enum.map(fn {_, p} -> p end)
      |> Enum.split_while(fn %{name: name} -> name != target_name end)

    tail ++ head
  end
end

# Enum.split_with(game_state, fn %{name: name} -> name == "mario" end)
# game_state = [%{name: "jeff"}, %{name: "mario"}, %{name: "ale"}]
