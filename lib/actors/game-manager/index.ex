defmodule Actors.GameManager do
  @moduledoc """
  Actors.GameManager
  """
  @gamemanager :gamemanager
  @player_opt_in :player_opt_in
  @player_opt_out :player_opt_out
  @rejoin :rejoin

  use GenServer

  def start_link() do
    init_state = %{
      # {name: pid}
      players: %{},

      # {uuid: {table_manager_pid, game_desc }}
      active_games: %{},

      # {name: {uuid, game_desc }
      active_players: %{}
    }

    GenServer.start_link(__MODULE__, init_state, name: @gamemanager)
  end

  @impl true
  def handle_call({@player_opt_in, name, pid}, _from, %{players: players} = state) do
    count = (players |> Map.keys() |> length) + 1

    case Map.has_key?(players, name) do
      true ->
        {:reply, {:error, :user_already_registered}, state}

      false ->
        new_players = Map.put(players, name, pid)

        players_name =
          Enum.to_list(players)
          |> Enum.map(fn {_, %{name: n}} -> n end)
          |> Enum.join(", ")

        if count < 3 do
          msg = Messages.new_player_arrived(players_name, 3 - count)

          Enum.each(Enum.to_list(new_players), fn {_, %{pid: p}} ->
            GenServer.cast(p, {:success, msg})
          end)

          {:reply, {:ok, :user_opted_in, msg}, %{state | players: new_players}}
        else
          # TODO
          # 1. update active games
          # 2. create TableManager.Actor through TableManager.start_link(uuid) and the start_link function of the TableManager must do: GenServer.start_link(__MODULE__, ..., name: {global: uuid})
          # 3. clear the players Map so the GameManager can accept three new players
          # 4. save in a new map name -> TableManager.uuid so a rejoin logic can be implemented

          uuid = UUID.uuid4()
          {:ok, pid} = Actors.NewTableManager.start_link(UUID.uuid4(uuid, new_players))

          # Notify the players that the game is about to begin
          Enum.each(Enum.to_list(new_players), fn {_, %{pid: p}} ->
            GenServer.cast(p, {:start_game, pid})
          end)

          # Update state
          datetime = DateTime.utc_now()
          formatted_datetime = Calendar.strftime(datetime, "%A, %B %d, %Y %I:%M %p")
          game_desc = "#{Utils.Colors.with_underline(formatted_datetime)}: #{players_name}"

          new_active_players =
            Enum.to_list(new_players)
            |> Enum.map(fn {name, _} -> {name, [{uuid, game_desc}]} end)
            |> Enum.into(%{})
            |> Map.merge(state[:active_players], fn _key, v1, v1 -> v1 ++ v2 end)

          new_active_games = Map.put(state[:active_games], uuid, {pid, game_desc})

          new_state = %{
            state
            | players: %{},
              active_games: new_active_games,
              active_players: new_active_players
          }

          {:reply, {:ok, :game_start}, %{state | players: %{}}}
        end
    end
  end

  @impl true
  def handle_call({@player_opt_out, name}, _from, %{players: players} = state) do
    case Map.has_key?(players, name) do
      false ->
        {:reply, {:error, :user_not_registered}, state}

      true ->
        new_players = Map.delete(players, name)

        players_name =
          Enum.to_list(new_players)
          |> Enum.map(fn {_, %{name: n}} -> n end)
          |> Enum.join(" ")

        Enum.each(Enum.to_list(new_players), fn {_, %{pid: p}} ->
          GenServer.cast(p, {:success, Actors.Lobby.Messages.player_opt_out(players_name, name, map_size(new_players))})
        end)

        {:reply, {:ok, Actors.Lobby.Messages.opt_out_success()}, %{state | players: new_players}}
    end
  end

  @impl true
  def handle_call({@rejoin, name}, _from, state) do
    # TODO: player type rejoin and the game manager returns all the games he is playing if any
    # we can retrieve that info from state[:active_players]
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({@rejoin, name, uuid, player_pid}, _from, state) do
    # TODO: with the uuid returned to the prev step, the user chose which game to rejoin.
    # witht the uuid we can retrieve the TableManager uuid and call him to ask him to
    # switch the old_player_pid with the new player_pid so the player can rejoin the game
    {:reply, :ok, state}
  end

  @impl true
  def init(init_state) do
    {:ok, init_state}
  end

  # Public API
  def add_player(name) do
    GenServer.call(self(), {@player_opt_in, name})
  end

  def remove_player(name) do
    GenServer.cast(self(), {@player_opt_out, name})
  end
end
