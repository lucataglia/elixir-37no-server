# IO.puts("set card AFTER: " <> inspect(Map.put(game_state[:players][name], :current, card), pretty: true, syntax_colors: [atom: :cyan, string: :green]))

defmodule Actors.TableManager do
  @moduledoc """
  Actor.TableManager
  """

  use GenServer

  defp init_state(),
    do: %{
      behavior: :opt_in,
      deck: Deck.shuffle(),
      # %{
      #   [name]: %{ [name]: %{key, label, suit, pretty, ranking, point}}
      # }
      current_turn: [],

      # Because the next game it must me (game_dealer_index + 1) % 3
      game_dealer_index: nil,

      # User in STATE - REPLAY
      want_to_replay: [],

      # %{
      #   turn_first_card: %{label, suit, pretty, ranking, point},
      #   dealer_index: [0..2]
      #   used_card_count: 0,
      #   leaderboard: []
      #   players: %{ [name]: %{pid, name, cards, points,  leaderboard, index, current, stack, is_looser, is_stopped}}
      # }
      game_state: %{turn_first_card: nil, dealer_index: nil, used_card_count: 0, info: "", turn_winner: "", players: %{}}
    }

  defp end_game_init_state(there_is_a_looser, game_dealer_index, players),
    do: %{
      behavior: :end_game,
      there_is_a_looser: there_is_a_looser,
      deck: Deck.shuffle(),
      # %{
      #   [name]: %{ [name]: %{key, label, suit, pretty, ranking, point}}
      # }
      current_turn: [],

      # Because the next game it must me (game_dealer_index + 1) % 3
      game_dealer_index: game_dealer_index,

      # User in STATE - REPLAY
      want_to_replay: [],

      # %{
      #   turn_first_card: %{label, suit, pretty, ranking, point},
      #   dealer_index: [0..2]
      #   used_card_count: 0,
      #   leaderboard: []
      #   players: %{ [name]: %{pid, name, cards, points, leaderboard, index, current, stack, is_looser, is_stopped}}
      # }
      game_state: %{turn_first_card: nil, dealer_index: game_dealer_index, used_card_count: 0, info: "", turn_winner: "", players: players}
    }

  def start_link() do
    GenServer.start_link(__MODULE__, init_state(), name: :tablemanager)
  end

  # STOP
  def handle_cast({:player_stop, name}, %{game_state: game_state} = state) do
    players = game_state[:players]
    new_player = %{players[name] | is_stopped: true}
    new_game_state = %{game_state | players: Map.put(players, name, new_player)}

    # Tells who is the new dealer
    Enum.each(Enum.to_list(game_state[:players]), fn {_, %{pid: p}} ->
      GenServer.cast(p, {:game_state_update, new_game_state, Actors.NewTableManager.Messages.player_exit_the_game(name)})
    end)

    {:noreply, %{state | game_state: new_game_state}}
  end

  # LOGIN
  @impl true
  def handle_call(
        {:new_player, pid, name},
        _from,
        %{game_state: game_state, deck: deck, behavior: :opt_in} = state
      ) do
    dealer_index = game_state[:dealer_index]

    players = game_state[:players]
    count = (players |> Map.keys() |> length) + 1

    case Map.has_key?(players, name) do
      true ->
        {:reply, {:error, :user_already_registered}, state}

      false ->
        new_player = %{
          pid: pid,
          name: name,
          points: 0,
          index: count - 1,
          current: nil,
          leaderboard: [],
          stack: [],
          cards: Map.new(Enum.at(deck, count - 1)),
          is_looser: false,
          is_stopped: false
        }

        new_players = Map.put(players, name, new_player)
        new_game_state = %{game_state | players: new_players}

        if count < 3 do
          players_name =
            Enum.to_list(players)
            |> Enum.map(fn {_, %{name: n}} -> n end)
            |> Enum.join(", ")

          msg = Messages.new_player_arrived(players_name, 3 - count)

          Enum.each(Enum.to_list(new_players), fn {_, %{pid: p}} ->
            GenServer.cast(p, {:success, msg})
          end)

          {:reply, {:ok, :user_opted_in, msg}, %{state | game_state: new_game_state, behavior: :opt_in}}
        else
          Enum.each(Enum.to_list(new_players), fn {_, %{pid: p, index: i}} ->
            if i == dealer_index do
              GenServer.cast(p, {:dealer, new_game_state})
            else
              GenServer.cast(p, {:better, new_game_state})
            end
          end)

          {:reply, {:ok, :game_start}, %{state | game_state: new_game_state, behavior: :game}}
        end
    end
  end

  # REMOVE PLAYER
  @impl true
  def handle_call({:remove_player, name}, _from, %{game_state: game_state, behavior: :opt_in} = state) do
    players = game_state[:players]

    case Map.has_key?(players, name) do
      false ->
        {:reply, {:error, :user_not_registered}, state}

      true ->
        new_players = Map.delete(game_state[:players], name)
        new_game_state = %{game_state | players: new_players}

        players_name =
          Enum.to_list(new_players)
          |> Enum.map(fn {_, %{name: n}} -> n end)
          |> Enum.join(" ")

        Enum.each(Enum.to_list(new_players), fn {_, %{pid: p}} ->
          GenServer.cast(p, {:success, Actors.Lobby.Messages.player_opt_out(players_name, name, map_size(new_players))})
        end)

        {:reply, {:ok, Actors.Lobby.Messages.opt_out_success()}, %{state | game_state: new_game_state}}
    end
  end

  # GAME
  @impl true
  def handle_cast({:choice, name, card}, %{current_turn: current_turn, game_dealer_index: game_dealer_index, game_state: game_state, behavior: :game} = state) do
    dealer_index = game_state[:dealer_index]
    used_card_count = game_state[:used_card_count]
    new_current_turn = [{name, card} | current_turn]
    new_used_card_count = used_card_count + 1

    cards = game_state[:players][name][:cards]

    update_used_card = Map.put(game_state[:players][name][:cards][String.to_atom(card[:key])], :used, true)
    new_cards = Map.put(cards, String.to_atom(card[:key]), update_used_card)

    cond do
      # NEW TURN
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
            {new_players_with_leaderboard, there_is_a_looser} =
              new_game_state[:players]
              |> Enum.to_list()
              |> Enum.map(fn {n, p} ->
                points_sum = p[:stack] |> Enum.map(fn {_, %{points: p}} -> p end) |> Enum.sum()

                new_points =
                  cond do
                    new_game_state[:turn_winner] == n ->
                      cond do
                        points_sum < 1 -> 11
                        # divide per 1.0 is to force the number to be float
                        true -> Float.ceil(points_sum / 1.0) |> trunc()
                      end

                    true ->
                      cond do
                        points_sum < 1 -> 11
                        # divide per 1.0 is to force the number to be float
                        true -> Float.floor(points_sum / 1.0) |> trunc()
                      end
                  end

                new_leaderboard = [new_points | p[:leaderboard]]
                is_looser = Enum.sum(new_leaderboard) > 21

                new_p =
                  p
                  |> Map.put(:points, new_points)
                  |> Map.put(:leaderboard, new_leaderboard)
                  |> Map.put(:is_looser, is_looser)

                {n, new_p, is_looser}
              end)
              |> Enum.reduce({%{}, false}, fn {n, p, is_looser}, {acc_p, acc_is_looser} -> {Map.put(acc_p, n, p), is_looser || acc_is_looser} end)

            new_game_state_with_leaderboard = %{new_game_state | dealer_index: nil, players: new_players_with_leaderboard}

            # Tells :end_game to the players
            new_players_with_leaderboard
            |> Enum.to_list()
            |> Enum.each(fn {_, %{pid: p}} -> GenServer.cast(p, {:end_game, new_game_state_with_leaderboard}) end)

            case there_is_a_looser do
              true ->
                new_game_dealer_index =
                  case dealer_index do
                    nil -> Enum.random(0..2)
                    _ -> dealer_index
                  end

                end_game_state = end_game_init_state(there_is_a_looser, new_game_dealer_index, new_players_with_leaderboard)

                # RETURN
                {:noreply, end_game_state}

              false ->
                new_game_dealer_index = rem(game_dealer_index + 1, 3)
                end_game_state = end_game_init_state(there_is_a_looser, new_game_dealer_index, new_players_with_leaderboard)

                # RETURN
                {:noreply, end_game_state}
            end

          # GAME NOT ENDED
          true ->
            # Tells who is the new dealer
            Enum.each(Enum.to_list(game_state[:players]), fn {_, %{pid: p, index: i}} ->
              cond do
                new_game_state[:dealer_index] == i -> GenServer.cast(p, {:dealer, new_game_state})
                true -> GenServer.cast(p, {:better, new_game_state})
              end
            end)

            # RETURN
            {:noreply, %{state | game_state: new_game_state, current_turn: []}}
        end

      # SAME TURN
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
  def handle_cast({:replay, name}, %{behavior: :end_game, there_is_a_looser: false} = state) do
    handle_end_game({:replay, {name, false}}, state)
  end

  @impl true
  def handle_cast({:replay, name}, %{behavior: :end_game, there_is_a_looser: true} = state) do
    handle_end_game({:replay, {name, true}}, state)
  end

  defp handle_end_game({:replay, {name, clear_leaderboard}}, %{want_to_replay: want_to_replay, game_dealer_index: game_dealer_index, game_state: game_state, behavior: :end_game} = state) do
    IO.puts("#{name} want to replay")

    players = game_state[:players]
    new_want_to_replay = [name | want_to_replay]

    case length(new_want_to_replay) do
      3 ->
        deck = state[:deck]

        new_init_players =
          players
          |> Enum.to_list()
          |> Enum.reduce(%{}, fn {n, p}, acc ->
            new_player = %{
              p
              | points: 0,
                current: nil,
                stack: [],
                leaderboard:
                  case clear_leaderboard do
                    true -> []
                    false -> p[:leaderboard]
                  end,
                is_looser: false,
                cards: Map.new(Enum.at(deck, p[:index] - 1))
            }

            Map.put(acc, n, new_player)
          end)

        new_game_state = %{state[:game_state] | players: new_init_players}

        # Inform who is the DEALER and who is the BETTER
        Enum.each(Enum.to_list(new_init_players), fn {_, %{pid: p, index: i}} ->
          cond do
            i == game_dealer_index -> GenServer.cast(p, {:dealer, new_game_state})
            i != game_dealer_index -> GenServer.cast(p, {:better, new_game_state})
          end
        end)

        {:noreply, %{state | game_state: new_game_state, behavior: :game}}

      _ ->
        Enum.each(Enum.to_list(players), fn {_, %{pid: p}} ->
          GenServer.cast(p, {:message, Actors.NewTableManager.Messages.wants_to_replay(new_want_to_replay)})
        end)

        {:noreply, %{state | want_to_replay: new_want_to_replay}}
    end
  end

  @impl true
  def init(initial_state) do
    IO.puts("Table Manager init")

    new_dealer_index = Enum.random(0..2)

    {:ok,
     %{
       initial_state
       | game_dealer_index: new_dealer_index,
         game_state: %{initial_state[:game_state] | dealer_index: new_dealer_index}
     }}
  end

  # LOBBY

  # *** Public api ***
  def add_player(pid, name) do
    GenServer.call(:tablemanager, {:new_player, pid, name})
  end

  def remove_player(name) do
    GenServer.call(:tablemanager, {:remove_player, name})
  end

  def send_choice(name, card) do
    GenServer.cast(:tablemanager, {:choice, name, card})
  end

  def replay(name) do
    GenServer.cast(:tablemanager, {:replay, name})
  end

  def player_stop(name) do
    GenServer.cast(:tablemanager, {:player_stop, name})
  end
end
