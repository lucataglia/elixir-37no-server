Code.require_file("deck.exs")
Code.require_file("table-manager.exs")
Code.require_file("messages.exs")

defmodule Player do
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

  # STOP
  @impl true
  def handle_cast({:stop}, state) do
    # TODO: inform the table manager
    {:stop, :normal, state}
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

  # STATE - UNNAMED
  @impl true
  def handle_cast({:recv, name}, %{behavior: :unnamed} = state) do
    TableManager.check_if_name_is_available(name)
    |> (fn
          true ->
            TableManager.add_player(self(), name)

            new_state = %{state | name: name, behavior: :login}
            {:noreply, new_state}

          false ->
            GenServer.cast(self(), {:warning, Messages.name_already_taken(name)})
            {:noreply, state}
        end).()
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
    turn_first_card = game_state[:turn_first_card]

    cards = game_state[:players][name][:cards]
    choice = deck[String.to_atom(data)]

    if choice do
      if Map.has_key?(cards, String.to_atom(data)) do
        case Deck.is_a_valid_card(data, cards, turn_first_card) do
          "ok" ->
            TableManager.send_choice(name, choice)

          "ok-change-ranking" ->
            TableManager.send_choice(name, %{choice | raking: 0})

          "wrong-suit" ->
            piggyback = IO.ANSI.format([:yellow, Messages.you_have_to_play_the_right_suit(choice[:pretty], turn_first_card[:suit])])
            GenServer.cast(self(), {:message, Messages.print_table(game_state, name, piggyback)})

          "invalid-chars" ->
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

  def handle_cast({:better, game_state}, %{name: n, behavior: :dealer} = state) do
    GenServer.cast(self(), {:message, Messages.print_table(game_state, n)})

    {:noreply, %{state | game_state: game_state, behavior: :better}}
  end

  # BETTER
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

  def handle_cast({x, _}, state) do
    IO.inspect("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  # *** Public api ***
  def forward_data(pid, data) do
    GenServer.cast(pid, {:recv, data})
  end

  def stop(pid) do
    GenServer.cast(pid, {:stop})
  end
end
