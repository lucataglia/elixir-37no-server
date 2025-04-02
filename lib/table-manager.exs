Code.require_file("constants.exs")
Code.require_file("deck.exs")

defmodule TableManager do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, %{behavior: :login, players: []}, name: :tablemanager)
  end

  # LOGIN
  @impl true
  def handle_cast({:new_player, pid, name}, %{players: players, behavior: :login}) do
    new_players = [%{pid: pid, name: name} | players]

    if length(new_players) < 3 do
      Enum.each(new_players, fn %{pid: p} ->
        envelop = {
          :message,
          Constants.warning(
            "#{name} arrived. Waiting for other #{3 - length(new_players)} players ..."
          )
        }

        GenServer.cast(p, envelop)
      end)

      {:noreply, %{players: new_players, behavior: :login}}
    else
      init_game_state =
        new_players
        |> Enum.with_index()
        |> Enum.map(fn {%{pid: p} = player, index} ->
          cards = Map.new(Enum.at(Deck.shuffle(), index))

          GenServer.cast(p, {:gotolobby})

          player
          |> Map.put(:cards, cards)
          |> Map.put(:points, 0)
        end)
        |> Enum.shuffle()

      GenServer.cast(self(), :initgame)
      {:noreply, %{game_state: init_game_state, behavior: :lobby}}
    end
  end

  # LOBBY

  @impl true
  def handle_cast(:initgame, %{game_state: game_state} = state) do
    Enum.each(game_state, fn %{pid: p} ->
      GenServer.cast(p, {:print, game_state})
    end)

    {:noreply, state}
  end

  @impl true
  def init(initial_state) do
    IO.puts("Table Manager init")

    {:ok, initial_state}
  end

  # LOBBY

  # *** Public api ***
  def add_player(pid, name) do
    IO.puts("Create #{name} player")

    GenServer.cast(:tablemanager, {:new_player, pid, name})
  end
end
