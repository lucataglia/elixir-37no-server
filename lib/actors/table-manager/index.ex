# IO.puts("set card AFTER: " <> inspect(Map.put(game_state[:players][name], :current, card), pretty: true, syntax_colors: [atom: :cyan, string: :green]))

defmodule Actors.NewTableManager do
  @moduledoc """
  Actor.NewTableManager
  """

  use GenServer

  @choice :choice
  @observer_leave :observer_leave
  @player_left_the_game :player_left_the_game
  @player_rejoin :player_rejoin
  @player_observe :player_observe
  @replay :replay

  defp init_state(raw_players),
    do: %{
      behavior: :game,
      deck: Deck.shuffle_and_chunk_deck(),
      # %{
      #   [name]: %{ [name]: %{key, label, suit, pretty, ranking, point}}
      # }
      current_turn: [],

      # Because the next game it must me (game_dealer_index + 1) % 3
      game_dealer_index: 0,

      # User in STATE - REPLAY
      want_to_replay: [],

      # %{
      #   turn_first_card: %{label, suit, pretty, ranking, point},
      #   dealer_index: [0..2]
      #   used_card_count: 0,
      #   info: ""
      #   turn_winner: ""
      #   there_is_a_looser: ""
      #   observers: %{name => pid}
      #   players: %{ [name]: %{pid, name, cards, points,  leaderboard, index, current, last, stack, is_looser, is_stopped}}
      # }
      game_state: %{turn_first_card: nil, dealer_index: 0, used_card_count: 0, info: "", turn_winner: "", there_is_a_looser: false, players: raw_players, observers: %{}}
    }

  defp end_game_init_state(there_is_a_looser, game_dealer_index, players, observers),
    do: %{
      behavior: :end_game,
      deck: Deck.shuffle_and_chunk_deck(),
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
      #   info: ""
      #   turn_winner: ""
      #   there_is_a_looser: ""
      #   observers: %{name => pid}
      #   players: %{ [name]: %{pid, name, cards, points, leaderboard, index, current, last, stack, is_looser, is_stopped}}
      # }
      game_state: %{turn_first_card: nil, dealer_index: game_dealer_index, used_card_count: 0, info: "", turn_winner: "", there_is_a_looser: there_is_a_looser, players: players, observers: observers}
    }

  def start_link(uuid, raw_players) do
    GenServer.start_link(__MODULE__, init_state(raw_players), name: {:global, uuid})
  end

  # LEFT THE GAME
  def handle_cast({@player_left_the_game, name}, %{game_state: game_state} = state) do
    players = game_state[:players]
    new_player = %{players[name] | is_stopped: true}
    new_game_state = %{game_state | players: Map.put(players, name, new_player)}

    # Tells who is the new dealer
    Enum.each(Enum.to_list(game_state[:players]), fn {_, %{pid: p}} ->
      Actors.Player.game_state_update(
        p,
        %{new_game_state: new_game_state},
        Actors.NewTableManager.Messages.player_left_the_game(name)
      )
    end)

    {:noreply, %{state | game_state: new_game_state}}
  end

  # REJOIN
  @impl true
  def handle_cast({@player_rejoin, name, player_pid}, %{game_state: game_state} = state) do
    dealer_index = game_state[:dealer_index]
    players = game_state[:players]
    is_dealer = players[:index] == dealer_index

    new_players = %{players | name => %{players[name] | pid: player_pid}}
    new_game_state = %{game_state | players: new_players}

    Actors.Player.rejoin_success(
      player_pid,
      %{
        table_manager_pid: self(),
        new_game_state: new_game_state,
        is_dealer: is_dealer,
        piggiback: Actors.NewTableManager.Messages.rejoin_success()
      }
    )

    Enum.each(Enum.to_list(players), fn {_, %{pid: p}} ->
      Actors.Player.game_state_update(
        p,
        %{new_game_state: new_game_state},
        Actors.NewTableManager.Messages.player_rejoined_the_game(name)
      )
    end)

    {:noreply, %{state | game_state: new_game_state}}
  end

  # OBSERVE
  @impl true
  def handle_cast({@player_observe, name, pid}, %{game_state: game_state} = state) do
    observers = game_state[:observers]
    new_observers = Map.put(observers, name, pid)
    new_game_state = %{game_state | observers: new_observers}

    Actors.Player.join_as_observer(
      pid,
      %{
        new_game_state: new_game_state,
        piggiback: Actors.NewTableManager.Messages.observe_success()
      }
    )

    {:noreply, %{state | game_state: new_game_state}}
  end

  @impl true
  def handle_call({@observer_leave, name}, _from, %{game_state: game_state} = state) do
    observers = game_state[:observers]

    if Map.has_key?(observers, name) do
      new_observers = Map.delete(observers, name)
      new_game_state = %{game_state | observers: new_observers}

      {:reply, {:ok}, %{state | game_state: new_game_state}}
    else
      {:reply, {:error, Actors.NewTableManager.Messages.observe_leave_error(name)}}
    end
  end

  # GAME
  @impl true
  def handle_cast({@choice, name, card}, %{current_turn: current_turn, game_dealer_index: game_dealer_index, game_state: game_state, behavior: :game} = state) do
    dealer_index = game_state[:dealer_index]
    used_card_count = game_state[:used_card_count]
    observers = game_state[:observers]
    new_current_turn = [{name, card} | current_turn]
    new_used_card_count = used_card_count + 1

    cards = game_state[:players][name][:cards]

    curr_card = game_state[:players][name][:cards][String.to_atom(card[:key])]
    update_used_card = Map.put(curr_card, :used, true)
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
              |> Map.put(:last, curr_card)

            winner_name != name ->
              game_state[:players][winner_name]
              |> Map.put(:stack, winner_new_stack)
              |> Map.put(:current, nil)
              |> Map.put(:last, game_state[:players][winner_name][:current])
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
              new_o1 = o1 |> Map.put(:current, nil) |> Map.put(:cards, new_cards) |> Map.put(:last, curr_card)
              new_o2 = o2 |> Map.put(:current, nil) |> Map.put(:last, o2[:current])

              {{name, new_o1}, {name_o2, new_o2}}

            [{name_o1, o1}, {name_o2, o2}] ->
              new_o1 = o1 |> Map.put(:current, nil) |> Map.put(:last, o1[:current])
              new_o2 = o2 |> Map.put(:current, nil) |> Map.put(:last, curr_card)

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
            info: "#{IO.ANSI.format([:yellow, :bright, winner_name])}: #{pretties}",
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

            new_game_state_with_leaderboard = %{new_game_state | there_is_a_looser: there_is_a_looser, dealer_index: nil, players: new_players_with_leaderboard}

            # Tells :end_game to the players
            new_players_with_leaderboard
            |> Enum.to_list()
            |> Enum.each(fn {_, %{pid: p}} -> Actors.Player.end_game(p, %{new_game_state: new_game_state_with_leaderboard}) end)

            Enum.to_list(observers)
            |> Enum.each(fn {_, pid} ->
              Actors.Player.game_state_update(
                pid,
                %{new_game_state: new_game_state}
              )
            end)

            case there_is_a_looser do
              true ->
                new_game_dealer_index =
                  case dealer_index do
                    nil -> Enum.random(0..2)
                    _ -> dealer_index
                  end

                end_game_state = end_game_init_state(there_is_a_looser, new_game_dealer_index, new_players_with_leaderboard, observers)

                # RETURN
                {:noreply, end_game_state}

              false ->
                new_game_dealer_index = rem(game_dealer_index + 1, 3)
                end_game_state = end_game_init_state(there_is_a_looser, new_game_dealer_index, new_players_with_leaderboard, observers)

                # RETURN
                {:noreply, end_game_state}
            end

          # GAME NOT ENDED
          true ->
            # Tells who is the new dealer
            Enum.each(Enum.to_list(game_state[:players]), fn {_, %{pid: p, index: i}} ->
              cond do
                new_game_state[:dealer_index] == i ->
                  Actors.Player.you_are_the_dealer(p, %{new_game_state: new_game_state})

                true ->
                  Actors.Player.you_are_the_better(p, %{new_game_state: new_game_state})
              end
            end)

            Enum.to_list(observers)
            |> Enum.each(fn {_, pid} ->
              Actors.Player.game_state_update(
                pid,
                %{new_game_state: new_game_state}
              )
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
              Actors.Player.you_are_the_dealer(p, %{new_game_state: new_game_state})

            true ->
              Actors.Player.you_are_the_better(p, %{new_game_state: new_game_state})
          end
        end)

        # RETURN
        {:noreply, %{state | game_state: new_game_state, current_turn: new_current_turn}}
    end
  end

  # END GAME
  @impl true
  def handle_cast({@replay, name}, %{behavior: :end_game, game_state: %{there_is_a_looser: false}} = state) do
    handle_end_game({@replay, {name, false}}, state)
  end

  @impl true
  def handle_cast({@replay, name}, %{behavior: :end_game, game_state: %{there_is_a_looser: true}} = state) do
    handle_end_game({@replay, {name, true}}, state)
  end

  defp handle_end_game({@replay, {name, clear_leaderboard}}, %{want_to_replay: want_to_replay, game_dealer_index: game_dealer_index, game_state: game_state, behavior: :end_game} = state) do
    IO.puts("#{name} want to replay")

    players = game_state[:players]
    observers = game_state[:observers]
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
                cards: Map.new(Enum.at(deck, p[:index]))
            }

            Map.put(acc, n, new_player)
          end)

        new_game_state = %{state[:game_state] | players: new_init_players}

        # Inform who is the DEALER and who is the BETTER
        Enum.each(Enum.to_list(new_init_players), fn {_, %{pid: p, index: i}} ->
          cond do
            i == game_dealer_index -> Actors.Player.you_are_the_dealer(p, %{new_game_state: new_game_state})
            i != game_dealer_index -> Actors.Player.you_are_the_better(p, %{new_game_state: new_game_state})
          end
        end)

        Enum.to_list(observers)
        |> Enum.each(fn {_, pid} ->
          Actors.Player.game_state_update(
            pid,
            %{new_game_state: new_game_state}
          )
        end)

        {:noreply, %{state | game_state: new_game_state, behavior: :game}}

      _ ->
        Enum.each(Enum.to_list(players), fn {_, %{pid: p}} ->
          Actors.Player.info_message(p, Actors.NewTableManager.Messages.wants_to_replay(new_want_to_replay))
        end)

        Enum.to_list(observers)
        |> Enum.each(fn {_, pid} ->
          Actors.Player.info_message(pid, Actors.NewTableManager.Messages.wants_to_replay(new_want_to_replay))
        end)

        {:noreply, %{state | want_to_replay: new_want_to_replay}}
    end
  end

  @impl true
  def init(%{deck: deck, game_dealer_index: game_dealer_index, game_state: game_state} = initial_state) do
    IO.puts("Table Manager init " <> inspect(self()))
    players = game_state[:players]

    [p1, p2, p3] =
      Utils.TestAware.shuffle(players)
      |> Enum.to_list()
      |> Enum.with_index()
      |> Enum.map(fn {{name, pid}, index} ->
        %{
          pid: pid,
          name: name,
          points: 0,
          index: index,
          current: nil,
          leaderboard: [],
          stack: [],
          cards: Map.new(Enum.at(deck, index)),
          is_looser: false,
          is_stopped: false
        }
      end)

    new_players = %{p1[:name] => p1, p2[:name] => p2, p3[:name] => p3}
    new_game_state = %{game_state | players: new_players}

    Enum.each(Enum.to_list(new_players), fn {_, %{pid: p, index: i}} ->
      if i == game_dealer_index do
        Actors.Player.start_game(p, self(), :dealer, new_game_state)
      else
        Actors.Player.start_game(p, self(), :better, new_game_state)
      end
    end)

    {:ok, %{initial_state | game_state: new_game_state}}
  end

  # *** Public api ***
  def send_choice(mode, name, card) do
    case mode do
      {:uuid, uuid} ->
        GenServer.cast({:global, uuid}, {@choice, name, card})

      {:pid, pid} ->
        GenServer.cast(pid, {@choice, name, card})
    end
  end

  def replay(mode, name) do
    case mode do
      {:uuid, uuid} -> GenServer.cast({:global, uuid}, {@replay, name})
      {:pid, pid} -> GenServer.cast(pid, {@replay, name})
    end
  end

  def player_left_the_game(mode, name) do
    case mode do
      {:uuid, uuid} -> GenServer.cast({:global, uuid}, {@player_left_the_game, name})
      {:pid, pid} -> GenServer.cast(pid, {@player_left_the_game, name})
    end
  end

  def player_rejoin(mode, name, player_pid) do
    case mode do
      {:uuid, uuid} -> GenServer.cast({:global, uuid}, {@player_rejoin, name, player_pid})
      {:pid, pid} -> GenServer.cast(pid, {@player_rejoin, name, player_pid})
    end
  end

  def player_observe(mode, name, player_pid) do
    case mode do
      {:uuid, uuid} -> GenServer.cast({:global, uuid}, {@player_observe, name, player_pid})
      {:pid, pid} -> GenServer.cast(pid, {@player_observe, name, player_pid})
    end
  end

  def observer_leave(mode, name) do
    case mode do
      {:uuid, uuid} -> GenServer.call({:global, uuid}, {@observer_leave, name})
      {:pid, pid} -> GenServer.call(pid, {@observer_leave, name})
    end
  end
end
