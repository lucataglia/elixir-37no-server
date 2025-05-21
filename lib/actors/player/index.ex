defmodule Actors.Player do
  @moduledoc """
  Actors.Player
  """
  alias Utils.Colors

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
    log(name, "start")

    GenServer.start(__MODULE__, init_state(client, name, lobby_pid))
  end

  def start_link(client, name, lobby_pid) do
    log(name, "start_link")

    GenServer.start_link(__MODULE__, init_state(client, name, lobby_pid))
  end

  # HANDLE INFO
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, {:table_manager_shutdown_due_to_inactivity, _uuid}} = reason}, %{name: name} = state) do
    log(name, ":DOWN TableManager #{inspect(pid)} exited with reason #{inspect(reason)}")

    {:stop, reason, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, :bridge_shutdown_client_exit} = reason}, %{name: name, table_manager_pid: table_manager_pid, behavior: behavior} = state) do
    log(name, ":DOWN Lobby #{inspect(pid)} exited with reason #{inspect(reason)}")

    case behavior do
      :init ->
        log(name, "behavior #{behavior} - do nothing")

        {:stop, reason, state}

      _ ->
        log(name, "behavior #{behavior} - NewTableManager.player_left_the_game")

        Actors.NewTableManager.player_left_the_game({:pid, table_manager_pid}, name)

        {:stop, reason, state}
    end

    {:stop, reason, state}
  end

  # PRINT MESSAGES
  @impl true
  def handle_cast({@msg_info, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.message(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({@msg_warning, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.warning(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({@msg_success, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.success(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({@print_table, piggyback}, %{client: client, name: name, stash: stash, game_state: game_state} = state) do
    :gen_tcp.send(client, Messages.print_table(game_state, name, piggyback: piggyback, stash: stash))
    {:noreply, state}
  end

  # *** ENDPRINT MESSAGES

  @impl true
  def handle_info(@broadcast_i_am_thinking_deeply, %{name: n, table_manager_pid: table_manager_pid} = state) do
    msg = Actors.Player.Messages.i_am_thinking_deeply(n)
    Actors.NewTableManager.broadcast_warning({:pid, table_manager_pid}, msg)

    {:noreply, state}
  end

  # GAME STATE UPDATE (e.g. some player exit the game)
  @impl true
  def handle_cast({@game_state_update, new_game_state, piggyback}, state) do
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
  def handle_cast({@observer, new_game_state, piggyback}, %{lobby_pid: lobby_pid} = state) do
    Actors.Lobby.game_start(lobby_pid)

    print_table(self(), Utils.Colors.with_yellow(piggyback))

    {:noreply, %{state | game_state: new_game_state, behavior: :observer}}
  end

  # REJOIN SUCCESS - as dealer
  @impl true
  def handle_cast({@rejoin_success, table_manager_pid, new_game_state, true, piggyback}, %{name: n, lobby_pid: lobby_pid} = state) do
    log(n, "Rejoin success as dealer")
    Actors.Lobby.game_start(lobby_pid)

    log(n, "monitor" <> inspect(table_manager_pid))
    Process.monitor(table_manager_pid)

    {:ok, ref} = :timer.send_interval(@timer_i_am_thinking_deeply, @broadcast_i_am_thinking_deeply)

    print_table(self(), Utils.Colors.with_yellow(piggyback))

    {:noreply, %{state | intervals: %{i_am_thinking_deeply: ref}, table_manager_pid: table_manager_pid, game_state: new_game_state, behavior: :dealer}}
  end

  # REJOIN SUCCESS - as better
  @impl true
  def handle_cast({@rejoin_success, table_manager_pid, new_game_state, false, piggyback}, %{name: n, lobby_pid: lobby_pid} = state) do
    log(n, "Rejoin success as better")
    Actors.Lobby.game_start(lobby_pid)

    log(n, "monitor" <> inspect(table_manager_pid))
    Process.monitor(table_manager_pid)

    print_table(self(), Utils.Colors.with_yellow(piggyback))

    {:noreply, %{state | table_manager_pid: table_manager_pid, game_state: new_game_state, behavior: :better}}
  end

  @impl true
  def handle_cast({@recv, "back"}, %{name: n, table_manager_pid: table_manager_pid} = state) do
    log(n, "back")

    Actors.NewTableManager.player_left_the_game({:pid, table_manager_pid}, n)

    {:stop, {:shutdown, :player_shutdown_left_the_game}, state}
  end

  # STATE - INIT (behavior is :dealer or :better)
  @impl true
  def handle_cast({@start_game, table_manager_pid, behavior, game_state}, %{name: n, lobby_pid: lobby_pid} = state) do
    log(n, "Start game " <> inspect(behavior))
    Actors.Lobby.game_start(lobby_pid)

    log(n, "monitor" <> inspect(table_manager_pid))
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

  # STATE - DEALER
  @impl true
  def handle_cast(
        {@recv, data},
        %{intervals: %{i_am_thinking_deeply: ref_i_am_thinking_deeply}, game_state: game_state, table_manager_pid: table_manager_pid, deck: deck, name: name, behavior: :dealer} = state
      ) do
    log(name, "recv: #{data}")

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

              {:ok, :change_ranking} ->
                :timer.cancel(ref_i_am_thinking_deeply)
                Actors.NewTableManager.send_choice({:pid, table_manager_pid}, name, %{choice | ranking: 0})

              {:error, :wrong_suit} ->
                piggyback = IO.ANSI.format([:yellow, Messages.you_have_to_play_the_right_suit(choice[:pretty], turn_first_card[:suit])])
                print_table(self(), piggyback)

              {:error, :card_already_used} ->
                piggyback = IO.ANSI.format([:yellow, Messages.card_already_used(choice[:pretty])])
                print_table(self(), piggyback)

              {:error, :invalid_input} ->
                piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
                print_table(self(), piggyback)
            end
          else
            piggyback = IO.ANSI.format([:yellow, Messages.you_dont_have_that_card(choice[:pretty])])
            print_table(self(), piggyback)
          end
        else
          piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
          print_table(self(), piggyback)
        end

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({@dealer, game_state}, %{behavior: :dealer} = state) do
    print_table(self())

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  @impl true
  def handle_cast({@better, game_state}, %{behavior: :dealer} = state) do
    print_table(self())

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  @impl true
  def handle_cast({@end_game, game_state}, %{name: name, behavior: :dealer} = state) do
    log(name, "game_state[:there_is_a_looser]: " <> inspect(game_state[:there_is_a_looser]))

    piggyback =
      if game_state[:there_is_a_looser] do
        "#{IO.ANSI.format([:magenta, :bright, Messages.game_ends_message()])}#{IO.ANSI.format([:yellow, Messages.type_replay_to_start_a_new_game()])}"
      else
        IO.ANSI.format([:yellow, Messages.type_replay_to_play_again()])
      end

    print_table(self(), piggyback)

    {:noreply, %{state | game_state: game_state, behavior: :end_game}}
  end

  # STATE - BETTER
  @impl true
  def handle_cast({@recv, data}, %{name: name, game_state: game_state, deck: deck, behavior: :better} = state) do
    turn_first_card = game_state[:turn_first_card]

    new_state =
      if turn_first_card == nil do
        warning_message(self(), Messages.wait_your_turn())

        state
      else
        case Utils.Regex.check_is_valid_card_key(data) do
          {:error, :invalid_input} ->
            piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
            print_table(self(), piggyback)

            state

          :ok ->
            turn_first_card = game_state[:turn_first_card]

            cards = game_state[:players][name][:cards]
            choice = deck[String.to_atom(data)]

            if choice do
              if Map.has_key?(cards, String.to_atom(data)) do
                case Deck.check_card_is_valid(data, cards, turn_first_card) do
                  :ok ->
                    log(name, "stash: #{inspect(choice.key)}")

                    print_table(self(), Actors.Player.Messages.card_stashed(choice.key))
                    %{state | stash: choice.key}

                  {:ok, :change_ranking} ->
                    log(name, "stash: #{inspect(choice.key)}")

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

  @impl true
  def handle_cast({@dealer, game_state}, %{name: n, stash: s, behavior: :better} = state) do
    print_table(self())

    {:ok, ref} = :timer.send_interval(@timer_i_am_thinking_deeply, @broadcast_i_am_thinking_deeply)

    if s do
      log(n, "unstash: #{inspect(s)}")

      GenServer.cast(self(), {@recv, s})
    end

    {:noreply, %{state | intervals: %{i_am_thinking_deeply: ref}, stash: nil, game_state: game_state, behavior: :dealer}}
  end

  @impl true
  def handle_cast({@better, game_state}, %{behavior: :better} = state) do
    print_table(self())

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  @impl true
  def handle_cast({@end_game, game_state}, %{behavior: :better} = state) do
    piggyback =
      if game_state[:there_is_a_looser] do
        "#{IO.ANSI.format([:magenta, :bright, Messages.game_ends_message()])}#{IO.ANSI.format([:yellow, Messages.type_replay_to_start_a_new_game()])}"
      else
        IO.ANSI.format([:yellow, Messages.type_replay_to_play_again()])
      end

    print_table(self(), piggyback)

    {:noreply, %{state | game_state: game_state, behavior: :end_game}}
  end

  # STATE - END GAME
  @impl true
  def handle_cast({@recv, data}, %{name: name, table_manager_pid: table_manager_pid, game_state: game_state, behavior: :end_game} = state) do
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

  # STATE - READY TO REPLY
  @impl true
  def handle_cast({@recv, data}, %{name: name, table_manager_pid: table_manager_pid, game_state: game_state, behavior: :ready_to_replay} = state) do
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
  def handle_cast({x, _}, %{name: n} = state) do
    log(n, "Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{name: n, lobby_pid: lobby_pid} = initial_state) do
    log(n, "Actor.Player init" <> inspect(self()))
    log(n, "Actor.Player monitor" <> inspect(lobby_pid))

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
      new_game_state: new_game_state,
      piggyback: piggyback
    } = args

    GenServer.cast(pid, {@observer, new_game_state, piggyback})
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
  defp log(n, msg) do
    IO.puts("#{Colors.with_light_magenta("Player")} #{Colors.with_underline(n)} #{msg}")
  end
end
