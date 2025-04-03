Code.require_file("messages.exs")
Code.require_file("deck.exs")

# IO.puts("set card AFTER: " <> inspect(Map.put(game_state[:players][name], :current, card), pretty: true, syntax_colors: [atom: :cyan, string: :green]))

defmodule TableManager do
  use GenServer

  defp init_state(),
    do: %{
      behavior: :login,
      deck: Deck.shuffle(),
      used_card_count: 0,
      # %{
      #   [name]: %{ [name]: %{key, label, suit, pretty, ranking, point}}
      # }
      current_turn: [],

      # %{
      #   turn_first_card: %{label, suit, pretty, ranking, point},
      #   dealer_index: [0..2]
      #   players: %{ [name]: %{pid, name, cards, points, index, current, stack}}
      # }
      game_state: %{turn_first_card: nil, dealer_index: nil, info: "", turn_winner: "", players: %{}}
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

    IO.puts("new_dealer_index: #{new_dealer_index}")

    players = game_state[:players]
    count = (players |> Map.keys() |> length) + 1

    new_player = %{
      pid: pid,
      name: name,
      points: 0,
      index: count - 1,
      current: nil,
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
  def handle_cast({:choice, name, card}, %{current_turn: current_turn, used_card_count: used_card_count, game_state: game_state, behavior: :game} = state) do
    dealer_index = game_state[:dealer_index]
    new_current_turn = [{name, card} | current_turn]
    new_used_card_count = used_card_count + 1

    new_turn_first_card =
      if game_state[:turn_first_card] do
        game_state[:turn_first_card]
      else
        card
      end

    new_dealer_index = rem(dealer_index + 1, 3)
    cards = game_state[:players][name][:cards]

    update_used_card = Map.put(game_state[:players][name][:cards][String.to_atom(card[:key])], :used, true)
    new_cards = Map.put(cards, String.to_atom(card[:key]), update_used_card)

    new_player =
      game_state[:players][name]
      |> Map.put(:current, card)
      |> Map.put(:cards, new_cards)

    IO.puts("FOO: " <> inspect(new_current_turn, pretty: true, syntax_colors: [atom: :cyan, string: :green]))

    {new_info, new_turn_winner} =
      cond do
        length(new_current_turn) == 3 ->
          [{name, _} | _] = new_current_turn |> Enum.sort_by(fn {_, %{ranking: r}} -> r end, :desc)
          pretties = new_current_turn |> Enum.map(fn {_, %{pretty: p}} -> p end) |> Enum.join(" ")
          {"#{IO.ANSI.format([:light_green, name])}: #{pretties}", name}

        length(new_current_turn) < 3 ->
          {"", ""}
      end

    new_game_state = %{
      game_state
      | turn_first_card: new_turn_first_card,
        dealer_index: new_dealer_index,
        info: new_info,
        turn_winner: new_turn_winner,
        players: Map.put(game_state[:players], name, new_player)
    }

    Enum.each(Enum.to_list(game_state[:players]), fn {_, %{pid: p, index: i}} ->
      if new_dealer_index == i do
        GenServer.cast(p, {:dealer, new_game_state})
      else
        GenServer.cast(p, {:better, new_game_state})
      end
    end)

    {:noreply, %{state | game_state: new_game_state, current_turn: new_current_turn, used_card_count: new_used_card_count}}
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
