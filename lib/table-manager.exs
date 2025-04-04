Code.require_file("messages.exs")
Code.require_file("deck.exs")

# IO.puts("set card AFTER: " <> inspect(Map.put(game_state[:players][name], :current, card), pretty: true, syntax_colors: [atom: :cyan, string: :green]))

defmodule TableManager do
  use GenServer

  defp init_state(),
    do: %{
      behavior: :login,
      deck: Deck.shuffle(),
      # %{
      #   [name]: %{ [name]: %{key, label, suit, pretty, ranking, point}}
      # }
      current_turn: [],

      # %{
      #   turn_first_card: %{label, suit, pretty, ranking, point},
      #   dealer_index: [0..2]
      #   used_card_count: 0,
      #   leaderboard: []
      #   players: %{ [name]: %{pid, name, cards, points, leaderboard, index, current, stack}}
      # }
      game_state: %{turn_first_card: nil, dealer_index: nil, used_card_count: 0, info: "", turn_winner: "", players: %{}}
    }

  def start_link() do
    GenServer.start_link(__MODULE__, init_state(), name: :tablemanager)
  end

  @impl true
  def handle_call({:check_is_name_available, name}, _from, %{game_state: game_state} = state) do
    players = game_state[:players]

    IO.puts("#{name} #{Map.has_key?(players, name)}")
    {:reply, !Map.has_key?(players, name), state}
  end

  # LOGIN
  @impl true
  def handle_cast(
        {:new_player, pid, name},
        %{game_state: game_state, deck: deck, behavior: :login} = state
      ) do
    dealer_index = game_state[:dealer_index]

    new_dealer_index =
      case dealer_index do
        nil -> Enum.random(0..2)
        _ -> dealer_index
      end

    players = game_state[:players]
    count = (players |> Map.keys() |> length) + 1

    new_player = %{
      pid: pid,
      name: name,
      points: 0,
      index: count - 1,
      current: nil,
      leaderboard: [],
      stack: [],
      cards: Map.new(Enum.at(deck, count - 1))
    }

    new_players = Map.put(players, name, new_player)
    new_game_state = %{game_state | players: new_players, dealer_index: new_dealer_index}

    if count < 3 do
      Enum.each(Enum.to_list(new_players), fn {_, %{pid: p}} ->
        playersName =
          Enum.to_list(new_players)
          |> Enum.map(fn {_, %{name: n}} -> n end)
          |> Enum.join(" ")

        msg = Messages.new_player_arrived(playersName, 3 - count)

        GenServer.cast(p, {:success, msg})
      end)

      {:noreply, %{state | game_state: new_game_state, behavior: :login}}
    else
      Enum.each(Enum.to_list(new_players), fn {_, %{pid: p, index: i}} ->
        if i == new_dealer_index do
          GenServer.cast(p, {:dealer, new_game_state})
        else
          GenServer.cast(p, {:better, new_game_state})
        end
      end)

      {:noreply, %{state | game_state: new_game_state, behavior: :game}}
    end
  end

  # GAME
  @impl true
  def handle_cast({:choice, name, card}, %{current_turn: current_turn, game_state: game_state, behavior: :game} = state) do
    dealer_index = game_state[:dealer_index]
    used_card_count = game_state[:used_card_count]
    new_current_turn = [{name, card} | current_turn]
    new_used_card_count = used_card_count + 1

    cards = game_state[:players][name][:cards]

    update_used_card = Map.put(game_state[:players][name][:cards][String.to_atom(card[:key])], :used, true)
    new_cards = Map.put(cards, String.to_atom(card[:key]), update_used_card)

    cond do
      length(new_current_turn) == 3 ->
        [{winner_name, _} | _] = new_current_turn |> Enum.sort_by(fn {_, %{ranking: r}} -> r end, :desc)

        pretties =
          new_current_turn
          |> Enum.sort_by(fn {_, %{ranking: r}} -> r end, :desc)
          |> Enum.map(fn {_, %{pretty: p}} -> p end)
          |> Enum.join(" ")

        # Update winner player
        winner_index = game_state[:players][winner_name][:index]
        winner_new_stack = game_state[:players][winner_name][:stack] ++ new_current_turn

        new_player_winner =
          cond do
            winner_name == name ->
              game_state[:players][winner_name]
              |> Map.put(:cards, new_cards)
              |> Map.put(:stack, winner_new_stack)
              |> Map.put(:current, nil)

            winner_name != name ->
              game_state[:players][winner_name]
              |> Map.put(:stack, winner_new_stack)
              |> Map.put(:current, nil)
          end

        # Update other players
        other_players =
          game_state[:players]
          |> Enum.to_list()
          |> Enum.filter(fn {n, _} -> n !== winner_name end)
          |> Enum.sort_by(fn {n, _} -> n == name end, :desc)

        {{name_other1, other_player1}, {name_other2, other_player2}} =
          case other_players do
            [{^name, o1}, {name_o2, o2}] ->
              new_o1 = o1 |> Map.put(:current, nil) |> Map.put(:cards, new_cards)
              new_o2 = o2 |> Map.put(:current, nil)

              {{name, new_o1}, {name_o2, new_o2}}

            [{name_o1, o1}, {name_o2, o2}] ->
              new_o1 = o1 |> Map.put(:current, nil)
              new_o2 = o2 |> Map.put(:current, nil)

              {{name_o1, new_o1}, {name_o2, new_o2}}
          end

        new_players =
          game_state[:players]
          |> Map.put(winner_name, new_player_winner)
          |> Map.put(name_other1, other_player1)
          |> Map.put(name_other2, other_player2)

        # New game state
        new_game_state = %{
          game_state
          | turn_first_card: nil,
            dealer_index: winner_index,
            info: "#{IO.ANSI.format([:light_green, winner_name])}: #{pretties}",
            turn_winner: winner_name,
            used_card_count: new_used_card_count,
            players: new_players
        }

        cond do
          # END GAME
          new_used_card_count == Deck.card_count() ->
            # Update points and leaderboard
            new_players_with_leaderboard =
              new_game_state[:players]
              |> Enum.to_list()
              |> Enum.map(fn {n, p} ->
                points_sum = p[:stack] |> Enum.map(fn {_, %{points: p}} -> p end) |> Enum.sum()

                new_points =
                  cond do
                    new_game_state[:turn_winner] == n ->
                      cond do
                        points_sum < 1 -> 11
                        true -> Float.ceil(tot) |> trunc()
                      end

                    true ->
                      cond do
                        points_sum < 1 -> 11
                        true -> Float.floor(tot) |> trunc()
                      end
                  end

                new_leaderboard = [new_points | p[:leaderboard]]

                new_p = p |> Map.put(:points, new_points) |> Map.put(:leaderboard, new_leaderboard)

                {n, new_p}
              end)
              |> Enum.reduce(%{}, fn {n, p}, acc -> Map.put(acc, n, p) end)

            new_game_state_with_leaderboard = %{new_game_state | dealer_index: nil, players: new_players_with_leaderboard}

            # Tells :end_game to the players
            new_players_with_leaderboard
            |> Enum.to_list()
            |> Enum.each(fn {_, %{pid: p}} -> GenServer.cast(p, {:end_game, new_game_state_with_leaderboard}) end)

            # RETURN
            {:noreply, %{state | game_state: new_game_state_with_leaderboard, current_turn: [], behavior: :end_game}}

          # NEW TURN
          true ->
            # Tells who is the new dealer
            Enum.each(Enum.to_list(game_state[:players]), fn {_, %{pid: p, index: i}} ->
              cond do
                new_game_state[:dealer_index] == i ->
                  GenServer.cast(p, {:dealer, new_game_state})

                true ->
                  GenServer.cast(p, {:better, new_game_state})
              end
            end)

            # RETURN
            {:noreply, %{state | game_state: new_game_state, current_turn: []}}
        end

      true ->
        new_dealer_index = rem(dealer_index + 1, 3)
        new_turn_first_card = game_state[:turn_first_card] || card

        new_player =
          game_state[:players][name]
          |> Map.put(:current, card)
          |> Map.put(:cards, new_cards)

        new_game_state = %{
          game_state
          | turn_first_card: new_turn_first_card,
            dealer_index: new_dealer_index,
            used_card_count: new_used_card_count,
            players: game_state[:players] |> Map.put(name, new_player)
        }

        # Tells who is the new dealer
        Enum.each(Enum.to_list(game_state[:players]), fn {_, %{pid: p, index: i}} ->
          cond do
            new_game_state[:dealer_index] == i ->
              GenServer.cast(p, {:dealer, new_game_state})

            true ->
              GenServer.cast(p, {:better, new_game_state})
          end
        end)

        # RETURN
        {:noreply, %{state | game_state: new_game_state, current_turn: new_current_turn}}
    end
  end

  # END GAME
  @impl true
  def handle_cast({:replay, name}, %{behavior: :end_game}) do
    IO.puts("#{name} want to replay")
  end

  @impl true
  def init(initial_state) do
    IO.puts("Table Manager init")

    {:ok, initial_state}
  end

  # LOBBY

  # *** Public api ***
  def add_player(pid, name) do
    GenServer.cast(:tablemanager, {:new_player, pid, name})
  end

  def check_if_name_is_available(name) do
    GenServer.call(:tablemanager, {:check_is_name_available, name})
  end

  def send_choice(name, card) do
    GenServer.cast(:tablemanager, {:choice, name, card})
  end

  def replay(name) do
    GenServer.cast(:tablemanager, {:replay, name})
  end
end
