defmodule Actors.GameManager do
  @moduledoc """
  Actors.GameManager
  """
  alias Utils.Colors

  @gamemanager :gamemanager
  @player_opt_in :player_opt_in
  @player_opt_out :player_opt_out
  @list_open_tables :list_open_tables
  @list_all_open_tables :list_all_open_tables
  @observe :observe
  @rejoin :rejoin

  use GenServer

  def start_link() do
    init_state = %{
      # {name: pid}
      players: %{},

      # {uuid: {table_manager_pid, game_desc }}
      active_games: %{},

      # {name: {uuid, game_desc }}
      active_players: %{}
    }

    GenServer.start_link(__MODULE__, init_state, name: @gamemanager)
  end

  # HANDLE INFO
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, {:table_manager_shutdown_due_to_inactivity, uuid}} = reason}, %{active_games: active_games} = state) do
    log(":DOWN TableManager #{inspect(pid)} exited with reason #{inspect(reason)}")

    new_active_games = Map.delete(active_games, uuid)

    {:noreply, %{state | active_games: new_active_games}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, {:table_manager_shutdown_game_ended, uuid}} = reason}, %{active_games: active_games} = state) do
    log(":DOWN TableManager #{inspect(pid)} exited with reason #{inspect(reason)}")

    new_active_games = Map.delete(active_games, uuid)

    {:noreply, %{state | active_games: new_active_games}}
  end

  # *** END HANDLE INFO

  @impl true
  def handle_call({@player_opt_in, name, pid}, _from, %{players: players} = state) do
    log("#{name} opt_in")

    count = (players |> Map.keys() |> length) + 1

    case Map.has_key?(players, name) do
      true ->
        {:reply, {:error, :user_already_registered}, state}

      false ->
        new_players = Map.put(players, name, pid)

        players_name =
          Enum.to_list(new_players)
          |> Enum.map(fn {n, _} -> n end)
          |> Enum.join(", ")

        if count < 3 do
          msg = Messages.new_player_arrived(players_name, 3 - count)

          Enum.each(Enum.to_list(new_players), fn {_, player_pid} ->
            Actors.Player.success_message(player_pid, msg)
          end)

          {:reply, {:ok, :user_opted_in, msg}, %{state | players: new_players}}
        else
          uuid = UUID.uuid4()
          {:ok, table_manager_pid} = Actors.NewTableManager.start(uuid, new_players)
          Process.monitor(table_manager_pid)

          log("Game #{uuid} is starting")

          # Update state
          datetime = DateTime.utc_now()
          formatted_datetime = Calendar.strftime(datetime, "%A, %B %d, %Y %I:%M %p")
          game_desc = "#{formatted_datetime}: #{players_name}"

          new_active_players =
            Enum.to_list(new_players)
            |> Enum.map(fn {name, _} -> {name, [{uuid, game_desc}]} end)
            |> Enum.into(%{})
            |> Map.merge(state[:active_players], fn _key, v1, v2 -> v1 ++ v2 end)

          new_active_games = Map.put(state[:active_games], uuid, {table_manager_pid, game_desc})

          new_state = %{
            state
            | players: %{},
              active_games: new_active_games,
              active_players: new_active_players
          }

          {:reply, {:ok, :game_start}, new_state}
        end
    end
  end

  @impl true
  def handle_call({@player_opt_out, name}, _from, %{players: players} = state) do
    log("#{name} opt_out")

    case Map.has_key?(players, name) do
      false ->
        {:reply, {:error, :user_not_registered}, state}

      true ->
        new_players = Map.delete(players, name)

        players_name =
          Enum.to_list(new_players)
          |> Enum.map(fn {n, _} -> n end)
          |> Enum.join(" ")

        Enum.each(Enum.to_list(new_players), fn {_, p} ->
          GenServer.cast(p, {:success, Actors.Lobby.Messages.player_opt_out(players_name, name, map_size(new_players))})
        end)

        {:reply, {:ok, Actors.Lobby.Messages.opt_out_success()}, %{state | players: new_players}}
    end
  end

  @impl true
  def handle_call({@list_open_tables, name}, _from, %{active_players: active_players} = state) do
    log("#{name} list_open_tables")

    case active_players[name] do
      # list is [{game_uuid, game_desc}, ...]
      list when is_list(list) and list != [] ->
        {:reply, {:ok, list}, state}

      nil ->
        {:reply, {:ok, :no_active_game}, state}
    end
  end

  @impl true
  def handle_call({@list_all_open_tables}, from, %{active_games: active_games} = state) do
    log("#{inspect(from)} list_all_open_tables")

    list =
      Enum.to_list(active_games)
      |> Enum.map(fn {uuid, {_, game_desc}} -> {uuid, game_desc} end)

    {:reply, {:ok, list}, state}
  end

  @impl true
  def handle_call({@rejoin, name, uuid, player_pid}, _from, %{active_games: active_games} = state) do
    log("#{name} rejoin #{uuid}")

    case active_games[uuid] do
      {_, _} ->
        Actors.NewTableManager.player_rejoin({:uuid, uuid}, name, player_pid)

        {:reply, {:ok, :table_manager_informed}, state}

      nil ->
        {:reply, {:error, :game_does_not_exist}, state}
    end

    # TODO: with the uuid returned to the prev step, the user chose which game to rejoin.
    # witht the uuid we can retrieve the TableManager uuid and call him to ask him to
    # switch the old_player_pid with the new player_pid so the player can rejoin the game
  end

  @impl true
  def handle_call({@observe, name, uuid, player_pid}, _from, %{active_games: active_games} = state) do
    log("#{name} observe #{uuid}")

    case active_games[uuid] do
      {_, _} ->
        Actors.NewTableManager.player_observe({:uuid, uuid}, name, player_pid)

        {:reply, {:ok, :table_manager_informed}, state}

      nil ->
        {:reply, {:error, :game_does_not_exist}, state}
    end
  end

  @impl true
  def init(init_state) do
    {:ok, init_state}
  end

  # Public API
  def add_player(name, pid) do
    GenServer.call(@gamemanager, {@player_opt_in, name, pid})
  end

  def remove_player(name) do
    GenServer.call(@gamemanager, {@player_opt_out, name})
  end

  def list_open_tables(name) do
    GenServer.call(@gamemanager, {@list_open_tables, name})
  end

  def list_all_open_tables() do
    GenServer.call(@gamemanager, {@list_all_open_tables})
  end

  def rejoin(name, uuid, player_pid) do
    GenServer.call(@gamemanager, {@rejoin, name, uuid, player_pid})
  end

  def observe(name, uuid, player_pid) do
    GenServer.call(@gamemanager, {@observe, name, uuid, player_pid})
  end

  # *** private api
  defp log(msg) do
    IO.puts("#{Colors.with_cyan_bright("GameManager")} #{msg}")
  end
end
