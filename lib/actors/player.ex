defmodule Actors.Player do
  use GenServer

  defp init_state(client) do
    %{
      behavior: :unnamed,
      client: client,
      deck: Deck.factory(),
      name: "",
      game_state: %{}
    }
  end

  def start_link(client) do
    IO.puts("Player start_link")

    GenServer.start_link(__MODULE__, init_state(client))
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

  # GAME STATE UPDATE (e.g. some player exit the game)
  @impl true
  def handle_cast({:game_state_update, new_game_state, piggiback}, %{name: n} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(new_game_state, n, Utils.Colors.withYellow(piggiback))})
    {:noreply, %{state | game_state: new_game_state}}
  end

  # STOP
  @impl true
  def handle_cast({:stop}, %{name: n} = state) do
    Actors.TableManager.player_stop(n)
    {:stop, :normal, state}
  end

  # STATE - UNNAMED (TO BE MOVED INTO THE ACTOR.LOGIN
  @impl true
  def handle_cast({:recv, name}, %{behavior: :unnamed} = state) do
    case Utils.Regex.check_player_name(name) do
      {:error, :too_short} ->
        GenServer.cast(self(), {:warning, Messages.name_too_short()})
        {:noreply, state}

      {:error, :too_long} ->
        GenServer.cast(self(), {:warning, Messages.name_too_long()})
        {:noreply, state}

      {:error, :invalid_chars} ->
        GenServer.cast(self(), {:warning, Messages.name_contains_invalid_chars()})
        {:noreply, state}

      :ok ->
        case Actors.TableManager.check_if_name_is_available(name) do
          true ->
            Actors.TableManager.add_player(self(), name)

            GenServer.cast(self(), {:success, Messages.name_is_valid(name)})

            new_state = %{state | name: name, behavior: :login}
            {:noreply, new_state}

          false ->
            GenServer.cast(self(), {:warning, Messages.name_already_taken(name)})
            {:noreply, state}
        end
    end
  end

  # STATE - LOGIN

  @impl true
  def handle_cast({:recv, _}, %{behavior: :login} = state) do
    GenServer.cast(self(), {:warning, Messages.wait_for_game_start()})

    {:noreply, state}
  end

  def handle_cast({:dealer, game_state}, %{name: n, behavior: :login} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  def handle_cast({:better, game_state}, %{name: n, behavior: :login} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  # STATE - DEALER
  def handle_cast(
        {:recv, data},
        %{game_state: game_state, deck: deck, name: name, behavior: :dealer} = state
      ) do
    case Utils.Regex.is_valid_card_key(data) do
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
            case Deck.is_a_valid_card(data, cards, turn_first_card) do
              :ok ->
                Actors.TableManager.send_choice(name, choice)

              {:ok, :change_ranking} ->
                Actors.TableManager.send_choice(name, %{choice | ranking: 0})

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

  def handle_cast({:dealer, game_state}, %{name: n, behavior: :dealer} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  def handle_cast({:better, game_state}, %{name: n, behavior: :dealer} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  def handle_cast({:end_game, game_state}, %{name: name, behavior: :dealer} = state) do
    piggyback = IO.ANSI.format([:yellow, Messages.type_replay_to_play_again()])
    GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})

    {:noreply, %{state | game_state: game_state, behavior: :end_game}}
  end

  # STATE - BETTER
  def handle_cast({:recv, _}, %{behavior: :better} = state) do
    GenServer.cast(self(), {:message, Messages.wait_your_turn()})

    {:noreply, state}
  end

  def handle_cast({:dealer, game_state}, %{name: n, behavior: :better} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  def handle_cast({:better, game_state}, %{name: n, behavior: :better} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  def handle_cast({:end_game, game_state}, %{name: name, behavior: :better} = state) do
    piggyback = IO.ANSI.format([:yellow, Messages.type_replay_to_play_again()])
    GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})

    {:noreply, %{state | game_state: game_state, behavior: :end_game}}
  end

  # STATE - END GAME
  def handle_cast({:recv, data}, %{name: name, behavior: :end_game} = state) do
    case Utils.Regex.check_end_game_input(data) do
      {:replay} ->
        Actors.TableManager.replay(name)
        {:noreply, %{state | behavior: :ready_to_replay}}

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, Messages.end_game_invalid_input()})
        {:noreply, state}
    end
  end

  # STATE - READY TO REPLY
  def handle_cast({:recv, _}, %{behavior: :ready_to_replay} = state) do
    GenServer.cast(self(), {:warning, Messages.ready_to_replay_invalid_input()})

    {:noreply, state}
  end

  def handle_cast({:dealer, game_state}, %{name: n, behavior: :ready_to_replay} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :dealer}}
  end

  def handle_cast({:better, game_state}, %{name: n, behavior: :ready_to_replay} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    IO.inspect("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  # *** Public api ***
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
