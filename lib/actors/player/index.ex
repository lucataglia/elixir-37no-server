defmodule Actors.Player do
  @moduledoc """
  Actors.Player
  """

  use GenServer

  @timer_i_am_thinking_deeply 30_000

  @better :better
  @broadcast_i_am_thinking_deeply :broadcast_i_am_thinking_deeply
  @dealer :dealer
  @end_game :end_game
  @game_state_update :game_state_update
  @msg_info :message
  @msg_success :sucess
  @msg_warning :warning
  @observer :observer
  @print_table :print_table
  @recv :recv
  @rejoin_success :rejoin_success
  @start_game :start_game

  defp init_state(client, name, lobby_pid) do
    %{
      behavior: :init,
      client: client,
      intervals: %{
        i_am_thinking_deeply: nil
      },
      lobby_pid: lobby_pid,
      table_manager_pid: nil,
      deck: Deck.factory(),
      stash: nil,
      name: name,
      game_state: %{},
      game_uuid: nil
    }
  end

  def start(client, name, lobby_pid) do
    Utils.Log.log("Player", name, "start", &Utils.Colors.with_magenta/1)

    GenServer.start(__MODULE__, init_state(client, name, lobby_pid))
  end

  def start_link(client, name, lobby_pid) do
    Utils.Log.log("Player", name, "start_link", &Utils.Colors.with_magenta/1)

    GenServer.start_link(__MODULE__, init_state(client, name, lobby_pid))
  end

  # HANDLE INFO
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, {:table_manager_shutdown_due_to_inactivity, _uuid}} = reason}, %{name: name} = state) do
    Utils.Log.log("Player", name, ":DOWN TableManager #{inspect(pid)} exited with reason #{inspect(reason)}", &Utils.Colors.with_magenta/1)

    {:stop, reason, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, :bridge_shutdown_client_exit} = reason}, %{name: name, table_manager_pid: table_manager_pid, behavior: behavior} = state) do
    Utils.Log.log("Player", name, ":DOWN Lobby #{inspect(pid)} exited with reason #{inspect(reason)}", &Utils.Colors.with_magenta/1)

    case behavior do
      :init ->
        Utils.Log.log("Player", name, "behavior #{behavior} - do nothing", &Utils.Colors.with_magenta/1)

        {:stop, reason, state}

      :observer ->
        Utils.Log.log("Player", name, "behavior #{behavior} - NewTableManager.player_left_the_game", &Utils.Colors.with_magenta/1)

        Actors.NewTableManager.observer_leave({:pid, table_manager_pid}, name)

        {:stop, reason, state}

      _ ->
        Utils.Log.log("Player", name, "behavior #{behavior} - NewTableManager.player_left_the_game", &Utils.Colors.with_magenta/1)

        Actors.NewTableManager.player_left_the_game({:pid, table_manager_pid}, name)

        {:stop, reason, state}
    end

    {:stop, reason, state}
  end

  # PRINT MESSAGES
  @impl true
  def handle_cast({@msg_info, msg}, %{client: client} = state) do
    :ssl.send(client, Messages.message(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({@msg_warning, msg}, %{client: client} = state) do
    :ssl.send(client, Messages.warning(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({@msg_success, msg}, %{client: client} = state) do
    :ssl.send(client, Messages.success(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({@print_table, piggyback}, %{client: client, name: name, stash: stash, game_state: game_state, behavior: behavior} = state) do
    :ssl.send(client, Messages.print_table(game_state, name, piggyback: piggyback, stash: stash, behavior: behavior))
    {:noreply, state}
  end

  # *** ENDPRINT MESSAGES

  # BACK
  @impl true
  def handle_cast({@recv, "back"}, %{name: n, table_manager_pid: table_manager_pid, behavior: behavior} = state) do
    Utils.Log.log("Player", n, "back", &Utils.Colors.with_magenta/1)

    case behavior do
      :observer -> Actors.NewTableManager.observer_leave({:pid, table_manager_pid}, n)
      _ -> Actors.NewTableManager.player_left_the_game({:pid, table_manager_pid}, n)
    end

    {:stop, {:shutdown, :player_shutdown_left_the_game}, state}
  end

  # *** END BACK

  @impl true
  def handle_info(@broadcast_i_am_thinking_deeply, %{name: n, table_manager_pid: table_manager_pid} = state) do
    msg = Actors.Player.Messages.i_am_thinking_deeply(n)
    Actors.NewTableManager.broadcast_warning({:pid, table_manager_pid}, msg)

    {:noreply, state}
  end

  # GAME STATE UPDATE (e.g. some player exit the game)
  @impl true
  def handle_cast({@game_state_update, new_game_state, piggyback}, %{name: n, behavior: behavior} = state) do
    Utils.Log.log("Player", n, "game_state_update - #{behavior}", &Utils.Colors.with_magenta/1)

    print_table(self(), Utils.Colors.with_yellow(piggyback))

    {:noreply, %{state | game_state: new_game_state}}
  end

  @impl true
  def handle_cast({@game_state_update, new_game_state}, state) do
    print_table(self())

    {:noreply, %{state | game_state: new_game_state}}
  end

  # *** END GAME STATE UPDATE (e.g. some player exit the game)

  # JOIN AS OBSERVER
  @impl true
  def handle_cast({@observer, table_manager_pid, new_game_state, piggyback}, %{name: n, lobby_pid: lobby_pid} = state) do
    Actors.Lobby.game_start(lobby_pid)

    Utils.Log.log("Player", n, "monitor" <> inspect(table_manager_pid), &Utils.Colors.with_magenta/1)
    Process.monitor(table_manager_pid)

    print_table(self(), Utils.Colors.with_yellow(piggyback))

    {:noreply, %{state | table_manager_pid: table_manager_pid, game_state: new_game_state, behavior: :observer}}
  end

  # REJOIN SUCCESS - as dealer
  @impl true
  def handle_cast({@rejoin_success, table_manager_pid, new_game_state, true, piggyback}, %{name: n, lobby_pid: lobby_pid} = state) do
    Utils.Log.log("Player", n, "Rejoin success as dealer", &Utils.Colors.with_magenta/1)
    Actors.Lobby.game_start(lobby_pid)

    Utils.Log.log("Player", n, "monitor" <> inspect(table_manager_pid), &Utils.Colors.with_magenta/1)
    Process.monitor(table_manager_pid)

    {:ok, ref} = :timer.send_interval(@timer_i_am_thinking_deeply, @broadcast_i_am_thinking_deeply)

    print_table(self(), Utils.Colors.with_yellow(piggyback))

    {:noreply, %{state | intervals: %{i_am_thinking_deeply: ref}, table_manager_pid: table_manager_pid, game_state: new_game_state, behavior: :dealer}}
  end

  # REJOIN SUCCESS - as better
  @impl true
  def handle_cast({@rejoin_success, table_manager_pid, new_game_state, false, piggyback}, %{name: n, lobby_pid: lobby_pid} = state) do
    Utils.Log.log("Player", n, "Rejoin success as better", &Utils.Colors.with_magenta/1)
    Actors.Lobby.game_start(lobby_pid)

    Utils.Log.log("Player", n, "monitor" <> inspect(table_manager_pid), &Utils.Colors.with_magenta/1)
    Process.monitor(table_manager_pid)

    print_table(self(), Utils.Colors.with_yellow(piggyback))

    {:noreply, %{state | table_manager_pid: table_manager_pid, game_state: new_game_state, behavior: :better}}
  end

  # STATE - INIT (behavior is :dealer or :better)
  @impl true
  def handle_cast({@start_game, table_manager_pid, behavior, game_state}, %{name: n, lobby_pid: lobby_pid} = state) do
    Utils.Log.log("Player", n, "Start game " <> inspect(behavior), &Utils.Colors.with_magenta/1)
    Actors.Lobby.game_start(lobby_pid)

    Utils.Log.log("Player", n, "monitor" <> inspect(table_manager_pid), &Utils.Colors.with_magenta/1)
    Process.monitor(table_manager_pid)

    {:ok, ref} =
      if behavior == :dealer do
        :timer.send_interval(@timer_i_am_thinking_deeply, @broadcast_i_am_thinking_deeply)
      else
        {:ok, nil}
      end

    print_table(self(), Actors.Player.Messages.good_luck())

    {:noreply, %{state | intervals: %{i_am_thinking_deeply: ref}, table_manager_pid: table_manager_pid, behavior: behavior, game_state: game_state}}
  end

  # RECV
  @impl true
  def handle_cast({@recv, data}, %{name: n, table_manager_pid: table_manager_pid, behavior: behavior} = state) do
    Utils.Log.log("Player", n, "#{data} #{behavior}", &Utils.Colors.with_magenta/1)

    cond do
      String.downcase(data) =~ ~r/^obs yes [A-Za-z]{3,10}$/ ->
        [_, _, observer] = String.split(data, " ")

        case Actors.NewTableManager.accept_to__be_observed_by_someone({:pid, table_manager_pid}, n, observer) do
          {:error, :he_is_not_an_observer} ->
            warning_message(self(), ":he_is_not_an_observer")
            {:noreply, state}

          {:error, :player_does_not_exist} ->
            warning_message(self(), ":player_does_not_exist")
            {:noreply, state}

          {:error, :that_players_did_not_ask_to_observe} ->
            warning_message(self(), ":that_players_did_not_ask_to_observe")
            {:noreply, state}

          {:ok, _new_state} ->
            # TableManager will notify everyone with game_state_update
            {:noreply, state}
        end

      String.downcase(data) =~ ~r/^obs no [A-Za-z]{3,10}$/ ->
        [_, _, observer] = String.split(data, " ")

        case Actors.NewTableManager.reject_to__be_observed_by_someone({:pid, table_manager_pid}, n, observer) do
          {:error, :he_is_not_an_observer} ->
            warning_message(self(), ":he_is_not_an_observer")
            {:noreply, state}

          {:error, :player_does_not_exist} ->
            warning_message(self(), ":player_does_not_exist")
            {:noreply, state}

          {:error, :that_players_did_not_ask_to_observe} ->
            warning_message(self(), ":that_players_did_not_ask_to_observe")
            {:noreply, state}

          {:ok, _new_state} ->
            # TableManager will notify everyone with game_state_update
            {:noreply, state}
        end

      behavior == :observer ->
        observer_behavior(data, state)

      behavior == :dealer ->
        dealer_behavior(data, state)

      behavior == :dealer_with_choice ->
        dealer_with_choice_behavior(data, state)

      behavior == :better ->
        better_behavior(data, state)

      behavior == :end_game ->
        end_game_behavior(data, state)

      behavior == :ready_to_replay ->
        ready_to_replay_behavior(data, state)
    end
  end

  # STATE - DEALER_WITH_CHOICE
  @impl true
  def handle_cast({@dealer, game_state}, %{behavior: :dealer_with_choice} = state) do
    print_table(self())

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  @impl true
  def handle_cast({@better, game_state}, %{behavior: :dealer_with_choice} = state) do
    print_table(self())

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  # STATE - BETTER
  @impl true
  def handle_cast({@dealer, game_state}, %{name: n, stash: s, behavior: :better} = state) do
    print_table(self())

    {:ok, ref} = :timer.send_interval(@timer_i_am_thinking_deeply, @broadcast_i_am_thinking_deeply)

    if s do
      Utils.Log.log("Player", n, "unstash: #{inspect(s)}", &Utils.Colors.with_magenta/1)

      GenServer.cast(self(), {@recv, s})
    end

    {:noreply, %{state | intervals: %{i_am_thinking_deeply: ref}, stash: nil, game_state: game_state, behavior: :dealer}}
  end

  @impl true
  def handle_cast({@better, game_state}, %{behavior: :better} = state) do
    print_table(self())

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  # STATE - END GAME
  @impl true
  def handle_cast({@end_game, game_state}, %{name: name} = state) do
    Utils.Log.log("Player", name, "end_game - there_is_a_looser" <> inspect(game_state[:there_is_a_looser]), &Utils.Colors.with_magenta/1)

    print_table(self())

    {:noreply, %{state | game_state: game_state, behavior: :end_game}}
  end

  # STATE - READY TO REPLY
  @impl true
  def handle_cast({@dealer, game_state}, %{behavior: :ready_to_replay} = state) do
    print_table(self())

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  @impl true
  def handle_cast({@better, game_state}, %{behavior: :ready_to_replay} = state) do
    print_table(self())

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  # DEGUB that march everything
  @impl true
  def handle_cast(envelop, %{name: n, behavior: behavior} = state) do
    max_length = 100

    envelop_str = inspect(envelop)

    trimmed_envelop =
      if String.length(envelop_str) > max_length do
        String.slice(envelop_str, 0, max_length) <> "..."
      else
        envelop_str
      end

    Utils.Log.log_debug("Player", n, "Behavior: #{inspect(behavior)} | Received: #{trimmed_envelop}")

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{name: n, lobby_pid: lobby_pid} = initial_state) do
    Utils.Log.log("Player", n, "Actor.Player init" <> inspect(self()), &Utils.Colors.with_magenta/1)
    Utils.Log.log("Player", n, "Actor.Player monitor" <> inspect(lobby_pid), &Utils.Colors.with_magenta/1)

    Process.monitor(lobby_pid)

    {:ok, initial_state}
  end

  # *** Public api ***
  def start_game(pid, table_manager_pid, behavior, init_game_state) do
    GenServer.cast(pid, {@start_game, table_manager_pid, behavior, init_game_state})
  end

  def success_message(pid, msg) do
    GenServer.cast(pid, {@msg_success, msg})
  end

  def info_message(pid, msg) do
    GenServer.cast(pid, {@msg_info, msg})
  end

  def print_table(pid, piggyback \\ "") do
    GenServer.cast(pid, {@print_table, piggyback})
  end

  def warning_message(pid, msg) do
    GenServer.cast(pid, {@msg_warning, msg})
  end

  def forward_data(pid, data) do
    cond do
      data == "" -> warning_message(pid, "Invalid input")
      data != "" -> GenServer.cast(pid, {@recv, data})
    end
  end

  def game_state_update(pid, args, piggyback \\ "") do
    %{
      new_game_state: new_game_state
    } = args

    GenServer.cast(pid, {@game_state_update, new_game_state, piggyback})
  end

  def join_as_observer(pid, args) do
    %{
      table_manager_pid: table_manager_pid,
      new_game_state: new_game_state,
      piggyback: piggyback
    } = args

    GenServer.cast(pid, {@observer, table_manager_pid, new_game_state, piggyback})
  end

  def rejoin_success(pid, args) do
    %{
      table_manager_pid: table_manager_pid,
      new_game_state: new_game_state,
      is_dealer: is_dealer,
      piggyback: piggyback
    } = args

    GenServer.cast(pid, {@rejoin_success, table_manager_pid, new_game_state, is_dealer, piggyback})
  end

  def you_are_the_dealer(pid, args) do
    %{
      new_game_state: new_game_state
    } = args

    GenServer.cast(pid, {@dealer, new_game_state})
  end

  def you_are_the_better(pid, args) do
    %{
      new_game_state: new_game_state
    } = args

    GenServer.cast(pid, {@better, new_game_state})
  end

  def end_game(pid, args) do
    %{
      new_game_state: new_game_state
    } = args

    GenServer.cast(pid, {@end_game, new_game_state})
  end

  def player_shared_cards(pid, msg) do
    info_message(pid, msg)
  end

  def stop(pid) do
    GenServer.cast(pid, {:stop})
  end

  # *** private api

  defp observer_behavior(data, %{name: n, table_manager_pid: table_manager_pid, behavior: :observer} = state) do
    Utils.Log.log("Player", n, "Observe other player", &Utils.Colors.with_magenta/1)

    case Utils.Regex.check_observe_a_player(data) do
      {:ok, observed} ->
        Utils.Log.log("Player", n, "Observe other player: #{observed}", &Utils.Colors.with_magenta/1)

        case Actors.NewTableManager.ask_to_observe_someone({:pid, table_manager_pid}, n, observed) do
          {:error, :you_are_not_an_observer} ->
            warning_message(self(), "Something went wrong: You are not an observer\n")
            {:noreply, state}

          {:error, :player_does_not_exist} ->
            warning_message(self(), "Player #{observed} does not exist in this table\n")
            {:noreply, state}

          {:error, :you_already_ask_that_player} ->
            warning_message(self(), "Request already exist or previously rejected or accepted: obs #{observed}\n")
            {:noreply, state}

          {:ok, _new_state} ->
            # TableManager will notify everyone with game_state_update
            {:noreply, state}
        end

      {:error, :invalid_input} ->
        Utils.Log.log("Player", n, "Observe other player: invalid_input", &Utils.Colors.with_magenta/1)
        warning_message(self(), Actors.Player.Messages.invalid_input())

        {:noreply, state}
    end
  end

  defp dealer_behavior(
         data,
         %{intervals: %{i_am_thinking_deeply: ref_i_am_thinking_deeply}, game_state: game_state, table_manager_pid: table_manager_pid, deck: deck, name: name, behavior: :dealer} = state
       ) do
    Utils.Log.log("Player", name, "dealer_behavior - recv: #{data}", &Utils.Colors.with_magenta/1)

    case Utils.Regex.check_is_valid_card_key(data) do
      {:error, :invalid_input} ->
        piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
        print_table(self(), piggyback)

        {:noreply, state}

      :ok ->
        turn_first_card = game_state[:turn_first_card]

        cards = game_state[:players][name][:cards]
        choice = deck[String.to_atom(data)]

        if choice do
          if Map.has_key?(cards, String.to_atom(data)) do
            case Deck.check_card_is_valid(data, cards, turn_first_card) do
              :ok ->
                :timer.cancel(ref_i_am_thinking_deeply)
                Actors.NewTableManager.send_choice({:pid, table_manager_pid}, name, choice)

                {:noreply, %{state | behavior: :dealer_with_choice}}

              {:ok, :change_ranking} ->
                :timer.cancel(ref_i_am_thinking_deeply)
                Actors.NewTableManager.send_choice({:pid, table_manager_pid}, name, %{choice | ranking: 0})

                {:noreply, %{state | behavior: :dealer_with_choice}}

              {:error, :wrong_suit} ->
                piggyback = IO.ANSI.format([:yellow, Messages.you_have_to_play_the_right_suit(choice[:pretty], turn_first_card[:suit])])
                print_table(self(), piggyback)

                {:noreply, state}

              {:error, :card_already_used} ->
                piggyback = IO.ANSI.format([:yellow, Messages.card_already_used(choice[:pretty])])
                print_table(self(), piggyback)

                {:noreply, state}

              {:error, :invalid_input} ->
                piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
                print_table(self(), piggyback)

                {:noreply, state}
            end
          else
            piggyback = IO.ANSI.format([:yellow, Messages.you_dont_have_that_card(choice[:pretty])])
            print_table(self(), piggyback)

            {:noreply, state}
          end
        else
          piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
          print_table(self(), piggyback)

          {:noreply, state}
        end
    end
  end

  defp dealer_with_choice_behavior(data, %{name: n} = state) do
    Utils.Log.log("Player", n, "dealer_with_choice #{data}", &Utils.Colors.with_magenta/1)

    {:noreply, state}
  end

  defp better_behavior(data, %{name: name, game_state: game_state, deck: deck, behavior: :better} = state) do
    Utils.Log.log("Player", name, " better: #{data}", &Utils.Colors.with_magenta/1)

    cards = game_state[:players][name][:cards]
    turn_first_card = game_state[:turn_first_card]

    cards_list =
      Enum.to_list(cards)
      |> Enum.filter(fn {_, %{used: u}} -> !u end)
      |> Enum.map(fn {key, %{suit: s}} -> {key, s} end)

    {_first_key, first_suit} = Enum.at(cards_list, 0)

    all_same_suit =
      cards_list
      |> Enum.all?(fn {_key, suit} -> suit == first_suit end)

    new_state =
      cond do
        # If All the cards have the same suit you can stash whenever you want
        all_same_suit && Enum.find(cards_list, fn {key, _} -> key == String.to_atom(data) end) ->
          Utils.Log.log("Player", name, "stash (all_same_suit): #{inspect(data)} #{inspect(cards_list)}", &Utils.Colors.with_magenta/1)
          print_table(self(), Actors.Player.Messages.card_stashed(data))

          %{state | stash: data}

        # Otherwise, if the first player of the turn DID NOT play his card you CANNOT stash
        turn_first_card == nil ->
          warning_message(self(), "#{Messages.wait_your_turn()} #{data}")

          state

        # If the first player of the turn DID play his card you CAN stash
        true ->
          case Utils.Regex.check_is_valid_card_key(data) do
            {:error, :invalid_input} ->
              piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
              print_table(self(), piggyback)

              state

            :ok ->
              choice = deck[String.to_atom(data)]

              if choice do
                if Map.has_key?(cards, String.to_atom(data)) do
                  case Deck.check_card_is_valid(data, cards, turn_first_card) do
                    :ok ->
                      Utils.Log.log("Player", name, "stash: #{inspect(choice.key)}", &Utils.Colors.with_magenta/1)

                      print_table(self(), Actors.Player.Messages.card_stashed(choice.key))
                      %{state | stash: choice.key}

                    {:ok, :change_ranking} ->
                      Utils.Log.log("Player", name, "stash: #{inspect(choice.key)}", &Utils.Colors.with_magenta/1)

                      print_table(self(), Actors.Player.Messages.card_stashed(choice.key))
                      %{state | stash: choice.key}

                    {:error, :wrong_suit} ->
                      piggyback = IO.ANSI.format([:yellow, Messages.you_have_to_play_the_right_suit(choice[:pretty], turn_first_card[:suit])])
                      print_table(self(), piggyback)

                      state

                    {:error, :card_already_used} ->
                      piggyback = IO.ANSI.format([:yellow, Messages.card_already_used(choice[:pretty])])
                      print_table(self(), piggyback)

                      state

                    {:error, :invalid_input} ->
                      piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
                      print_table(self(), piggyback)

                      state
                  end
                else
                  piggyback = IO.ANSI.format([:yellow, Messages.you_dont_have_that_card(choice[:pretty])])
                  print_table(self(), piggyback)

                  state
                end
              else
                piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
                print_table(self(), piggyback)

                state
              end
          end
      end

    {:noreply, new_state}
  end

  defp end_game_behavior(data, %{name: name, table_manager_pid: table_manager_pid, behavior: :end_game} = state) do
    Utils.Log.log("Player", name, "end_game: #{data}", &Utils.Colors.with_magenta/1)

    case Utils.Regex.check_end_game_input(data) do
      {:share} ->
        case Actors.NewTableManager.share({:pid, table_manager_pid}, name) do
          {:ok} ->
            {:noreply, state}

          {:error, :already_shared} ->
            warning_message(self(), Actors.Player.Messages.card_already_shared())
            {:noreply, state}
        end

      {:replay} ->
        Actors.NewTableManager.replay({:pid, table_manager_pid}, name)
        {:noreply, %{state | behavior: :ready_to_replay}}

      {:error, :invalid_input} ->
        warning_message(self(), Messages.end_game_invalid_input())
        {:noreply, state}
    end
  end

  defp ready_to_replay_behavior(data, %{name: name, table_manager_pid: table_manager_pid, behavior: :ready_to_replay} = state) do
    Utils.Log.log("Player", name, "ready_to_replay: #{data}", &Utils.Colors.with_magenta/1)

    case Utils.Regex.check_end_game_input_ready_to_replay(data) do
      {:share} ->
        case Actors.NewTableManager.share({:pid, table_manager_pid}, name) do
          {:ok} ->
            {:noreply, state}

          {:error, :already_shared} ->
            warning_message(self(), Actors.Player.Messages.card_already_shared())
            {:noreply, state}
        end

      {:error, :invalid_input} ->
        warning_message(self(), Messages.end_game_invalid_input())
        {:noreply, state}
    end

    {:noreply, state}
  end
end
