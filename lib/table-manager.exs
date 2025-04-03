Code.require_file("messages.exs")
Code.require_file("deck.exs")

defmodule TableManager do
  use GenServer

  defp init_state(),
    do: %{
      behavior: :login,
      deck: Deck.shuffle(),
      dealer_index: nil,

      # %{
      #   [name]: %{ [name]: %{key, label, suit, pretty, ranking, point}}
      # }
      current_turn: [],

      # %{
      #   turn_first_card: %{label, suit, pretty, ranking, point},
      #   players: %{ [name]: %{pid, name, cards, points, index, is_dealer, current, stack}}
      # }
      game_state: %{turn_first_card: nil, players: %{}}
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
        %{game_state: game_state, dealer_index: dealer_index, deck: deck, behavior: :login} = state
      ) do
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
      is_dealer: new_dealer_index == count - 1,
      index: count - 1,
      current: "",
      stack: [],
      cards: Map.new(Enum.at(deck, count - 1))
    }

    new_players = Map.put(players, name, new_player)
    new_game_state = %{game_state | players: new_players}

    if count < 3 do
      Enum.each(Enum.to_list(new_players), fn {_, %{pid: p}} ->
        playersName =
          Enum.to_list(new_players)
          |> Enum.map(fn {_, %{name: n}} -> n end)
          |> Enum.join(" ")

        msg = Messages.new_player_arrived(playersName, 3 - count)

        GenServer.cast(p, {:success, msg})
      end)

      {:noreply, %{state | game_state: new_game_state, dealer_index: new_dealer_index, behavior: :login}}
    else
      Enum.each(Enum.to_list(new_players), fn {_, %{pid: p, is_dealer: is_dealer}} ->
        if is_dealer do
          GenServer.cast(p, {:dealer, new_game_state})
        else
          GenServer.cast(p, {:better, new_game_state})
        end
      end)

      {:noreply, %{state | game_state: new_game_state, dealer_index: new_dealer_index, behavior: :game}}
    end
  end

  # GAME
  @impl true

  def handle_cast({:choice, name, card}, %{current_turn: current_turn, dealer_index: dealer_index, game_state: game_state, behavior: :game} = state) do
    new_current_turn = [%{name: card} | current_turn]

    new_turn_first_card =
      if game_state[:turn_first_card] do
        game_state[:turn_first_card]
      else
        card
      end

    # TODO cards update is not working and we need also to update the is_dealer boolean because we are using it in the print_table
    new_player =
      game_state[:players][name]
      |> Map.put("current", card)
      |> Map.put("cards", Map.drop(game_state[:players][name][:cards], [card[:key]]))

    new_dealer_index = rem(dealer_index + 1, 3)
    new_game_state = %{game_state | turn_first_card: new_turn_first_card, players: Map.put(game_state[:players], name, new_player)}

    Enum.each(Enum.to_list(game_state[:players]), fn {_, %{pid: p, index: i}} ->
      if new_dealer_index == i do
        GenServer.cast(p, {:dealer, new_game_state})
      else
        GenServer.cast(p, {:better, new_game_state})
      end
    end)

    {:noreply, %{state | game_state: new_game_state, dealer_index: new_dealer_index, current_turn: new_current_turn}}
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
end
