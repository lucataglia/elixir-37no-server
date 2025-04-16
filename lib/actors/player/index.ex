defmodule Actors.Player do
  @moduledoc """
  Actors.Player
  """

  use GenServer

  defp init_state(client, name, parent_pid) do
    %{
      behavior: :init,
      client: client,
      parent_pid: parent_pid,
      table_manager_pid: nil,
      deck: Deck.factory(),
      name: name,
      game_state: %{},
      game_uuid: nil
    }
  end

  def start_link(client, name, parent_pid) do
    IO.puts("Player start_link")

    GenServer.start_link(__MODULE__, init_state(client, name, parent_pid))
  end

  # PRINT MESSAGES
  @impl true
  def handle_cast({:message, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.message(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:warning, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.warning(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:success, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.success(msg))
    {:noreply, state}
  end

  # *** ENDPRINT MESSAGES

  # GAME STATE UPDATE (e.g. some player exit the game)
  @impl true
  def handle_cast({:game_state_update, new_game_state, piggiback}, %{name: n} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(new_game_state, n, Utils.Colors.with_yellow(piggiback))})
    {:noreply, %{state | game_state: new_game_state}}
  end

  @impl true
  def handle_cast({:game_state_update, new_game_state}, %{name: n} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(new_game_state, n)})
    {:noreply, %{state | game_state: new_game_state}}
  end

  # *** END GAME STATE UPDATE (e.g. some player exit the game)

  # JOIN AS OBSERVER
  @impl true
  def handle_cast({:join_as_observer, new_game_state, piggiback}, %{name: n} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(new_game_state, n, Utils.Colors.with_yellow(piggiback))})
    {:noreply, %{state | game_state: new_game_state, behavior: :observer}}
  end

  # REJOIN SUCCESS - as dealer
  @impl true
  def handle_cast({:rejoin_success, new_game_state, true, piggiback}, %{name: n} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(new_game_state, n, Utils.Colors.with_yellow(piggiback))})
    {:noreply, %{state | game_state: new_game_state, behavior: :better}}
  end

  # REJOIN SUCCESS - as better
  @impl true
  def handle_cast({:rejoin_success, new_game_state, false, piggiback}, %{name: n} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(new_game_state, n, Utils.Colors.with_yellow(piggiback))})
    {:noreply, %{state | game_state: new_game_state, behavior: :dealer}}
  end

  # Handle :DOWN message when the parent dies
  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, %{name: name, table_manager_pid: table_manager_pid, behavior: :opted_in} = state) do
    IO.puts("Parent process stopped with reason: #{inspect(reason)}")

    # Perform cleanup or other actions before stopping
    Actors.NewTableManager.player_stop({:pid, table_manager_pid}, name)

    {:stop, :normal, state}
  end

  # STATE - INIT
  @impl true
  def handle_cast({:start_game, table_manager_pid}, state) do
    {:noreply, %{state | table_manager_pid: table_manager_pid}}
  end

  @impl true
  def handle_cast({:dealer, game_state}, %{name: n, parent_pid: parent_pid, behavior: :init} = state) do
    GenServer.cast(parent_pid, {:game_start})

    # Print the table with good luck
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n, Actors.Player.Messages.good_luck())})

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  @impl true
  def handle_cast({:better, game_state}, %{name: n, parent_pid: parent_pid, behavior: :init} = state) do
    GenServer.cast(parent_pid, {:game_start})

    # Print the table with good luck
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n, Actors.Player.Messages.good_luck())})

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  # STATE - DEALER
  @impl true
  def handle_cast(
        {:recv, data},
        %{game_state: game_state, table_manager_pid: table_manager_pid, deck: deck, name: name, behavior: :dealer} = state
      ) do
    case Utils.Regex.check_is_valid_card_key(data) do
      {:error, :invalid_input} ->
        piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
        GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})

        {:noreply, state}

      :ok ->
        turn_first_card = game_state[:turn_first_card]

        cards = game_state[:players][name][:cards]
        choice = deck[String.to_atom(data)]

        if choice do
          if Map.has_key?(cards, String.to_atom(data)) do
            case Deck.check_card_is_valid(data, cards, turn_first_card) do
              :ok ->
                Actors.NewTableManager.send_choice({:pid, table_manager_pid}, name, choice)

              {:ok, :change_ranking} ->
                Actors.NewTableManager.send_choice({:pid, table_manager_pid}, name, %{choice | ranking: 0})

              {:error, :wrong_suit} ->
                piggyback = IO.ANSI.format([:yellow, Messages.you_have_to_play_the_right_suit(choice[:pretty], turn_first_card[:suit])])
                GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})

              {:error, :invalid_input} ->
                piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
                GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})
            end
          else
            piggyback = IO.ANSI.format([:yellow, Messages.you_dont_have_that_card(choice[:pretty])])
            GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})
          end
        else
          piggyback = IO.ANSI.format([:yellow, Messages.unexisting_card(data)])
          GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})
        end

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:dealer, game_state}, %{name: n, behavior: :dealer} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  @impl true
  def handle_cast({:better, game_state}, %{name: n, behavior: :dealer} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  @impl true
  def handle_cast({:end_game, game_state}, %{name: name, behavior: :dealer} = state) do
    piggyback = IO.ANSI.format([:yellow, Messages.type_replay_to_play_again()])
    GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})

    {:noreply, %{state | game_state: game_state, behavior: :end_game}}
  end

  # STATE - BETTER
  @impl true
  def handle_cast({:recv, _}, %{behavior: :better} = state) do
    GenServer.cast(self(), {:message, Messages.wait_your_turn()})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:dealer, game_state}, %{name: n, behavior: :better} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  @impl true
  def handle_cast({:better, game_state}, %{name: n, behavior: :better} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  @impl true
  def handle_cast({:end_game, game_state}, %{name: name, behavior: :better} = state) do
    piggyback = IO.ANSI.format([:yellow, Messages.type_replay_to_play_again()])
    GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})

    {:noreply, %{state | game_state: game_state, behavior: :end_game}}
  end

  # STATE - END GAME
  @impl true
  def handle_cast({:recv, data}, %{name: name, table_manager_pid: table_manager_pid, behavior: :end_game} = state) do
    case Utils.Regex.check_end_game_input(data) do
      {:replay} ->
        Actors.NewTableManager.replay({:pid, table_manager_pid}, name)
        {:noreply, %{state | behavior: :ready_to_replay}}

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, Messages.end_game_invalid_input()})
        {:noreply, state}
    end
  end

  # STATE - READY TO REPLY
  @impl true
  def handle_cast({:recv, _}, %{behavior: :ready_to_replay} = state) do
    GenServer.cast(self(), {:warning, Messages.ready_to_replay_invalid_input()})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:dealer, game_state}, %{name: n, behavior: :ready_to_replay} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  @impl true
  def handle_cast({:better, game_state}, %{name: n, behavior: :ready_to_replay} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  # DEGUB that march everything
  @impl true
  def handle_cast({x, _}, state) do
    IO.puts("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{parent_pid: parent_pid} = initial_state) do
    IO.puts("Actor.Player init" <> inspect(self()))
    IO.puts("Actor.Player monitor" <> inspect(parent_pid))

    Process.monitor(parent_pid)

    {:ok, initial_state}
  end

  # *** Public api ***
  def start_game(pid, table_manager_pid) do
    GenServer.cast(pid, {:start_game, table_manager_pid})
  end

  def success_message(pid, msg) do
    GenServer.cast(pid, {:success, msg})
  end

  def forward_data(pid, data) do
    cond do
      data == "" -> GenServer.cast(pid, {:warning, "Invalid input"})
      data != "" -> GenServer.cast(pid, {:recv, data})
    end
  end

  def stop(pid) do
    GenServer.cast(pid, {:stop})
  end
end
