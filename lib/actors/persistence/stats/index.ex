defmodule Actors.Persistence.Stats do
  @moduledoc """
    Stats
  """
  alias Utils.Colors
  use GenServer

  @filename "user_stats.json"

  # Define all GenServer messages as module attributes
  @record_game :record_game
  @init_player :init_player
  @get_stats :get_stats

  # Client API
  def start() do
    GenServer.start(__MODULE__, nil, name: __MODULE__)
  end

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  # TERMINATE (for debug at the moment)
  @impl true
  def terminate(reason, state) do
    Utils.Log.log("PersistenceStats", "GenServer stopping with reason: #{inspect(reason)} and state: #{inspect(state)}", &Utils.Colors.with_yellow_and_underline/1)
    :ok
  end

  def get_stats(username) do
    GenServer.call(__MODULE__, {@get_stats, username})
  end

  def init_player(username) do
    GenServer.call(__MODULE__, {@init_player, username})
  end

  def record_game(username, players) do
    GenServer.cast(__MODULE__, {@record_game, username, players})
  end

  # Server Callbacks
  @impl true
  def init(_) do
    dir = Path.dirname(@filename)
    File.mkdir_p!(dir)
    full_path = Path.expand(@filename)

    Utils.Log.log("PersistenceStats", "Using stats file at: #{full_path}", &Utils.Colors.with_yellow_and_underline/1)

    state =
      case File.exists?(full_path) do
        true ->
          Utils.Log.log("PersistenceStats", "Loading stats from existing file.", &Utils.Colors.with_yellow_and_underline/1)
          load_from_disk(full_path)

        false ->
          Utils.Log.log("PersistenceStats", "Stats file not found. Creating new file with empty state.", &Utils.Colors.with_yellow_and_underline/1)
          File.write!(full_path, Jason.encode!(%{}))

          %{}
      end

    {:ok, state}
  end

  # Server Callback addition
  @impl true
  def handle_call({@init_player, username}, _from, state) do
    if Map.has_key?(state, username) do
      Utils.Log.log("PersistenceStats", "Attempted to initialize existing user #{Colors.with_underline(username)}", &Utils.Colors.with_yellow_and_underline/1)
      {:reply, {:error, :already_exists}, state}
    else
      default_stats = %{
        "played" => 0,
        "won" => 0,
        "last_game_desc" => "None",
        # Initialize as integer (will convert to Decimal on first game)
        "avg" => 0
      }

      new_state = Map.put(state, username, default_stats)
      save_to_disk(new_state)

      Utils.Log.log("PersistenceStats", "Initialized stats for new user #{Colors.with_underline(username)}", &Utils.Colors.with_yellow_and_underline/1)

      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({@get_stats, username}, _from, state) do
    stats = Map.get(state, username, %{played: 0, won: 0, last_game_desc: "None"})
    Utils.Log.log("PersistenceStats", "Retrieved stats for user #{Colors.with_underline(username)}: #{inspect(stats)}", &Utils.Colors.with_yellow_and_underline/1)

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_cast({@record_game, username, players}, state) do
    Utils.Log.log("PersistenceStats", "Record game #{Colors.with_underline(username)}", &Utils.Colors.with_yellow_and_underline/1)

    [{first_name, %{leaderboard: leaderboard_first}}, {second_name, %{leaderboard: leaderboard_second}}, {third_name, %{leaderboard: leaderboard_third}}] =
      players |> Enum.sort_by(fn {_, %{leaderboard: l}} -> Enum.sum(l) end)

    {_, me} = players |> Enum.find(fn {_, %{name: n}} -> n == username end)

    me_points = me[:leaderboard] |> Enum.sum()

    final_points_first = leaderboard_first |> Enum.sum()
    final_points_second = leaderboard_second |> Enum.sum()
    final_points_third = leaderboard_third |> Enum.sum()

    won = first_name == username

    Utils.Log.log("PersistenceStats", "Recording game for user #{Colors.with_underline(username)}, won: #{won}", &Utils.Colors.with_yellow_and_underline/1)

    new_state =
      Map.update(state, username, %{"played" => 1, "won" => if(won, do: 1, else: 0), "avg" => me_points}, fn user_stats ->
        old_played = user_stats["played"]
        old_avg = user_stats["avg"]
        old_won = user_stats["won"]

        # Convert existing avg and me_points to Decimal
        old_avg_decimal = Decimal.new(old_avg)
        old_played = old_played || 0
        new_points = Decimal.new(me_points)

        new_played = old_played + 1

        # Calculate: ((old_avg_decimal * old_played) + new_points) / new_played
        total_points = Decimal.add(Decimal.mult(old_avg_decimal, Decimal.new(old_played)), new_points)
        new_avg = Decimal.div(total_points, Decimal.new(new_played))

        %{
          "played" => old_played + 1,
          "won" => old_won + if(won, do: 1, else: 0),
          "last_game_desc" => "#{first_name}: #{final_points_first} - #{second_name}: #{final_points_second} - #{third_name}: #{final_points_third}",
          "avg" => new_avg
        }
      end)

    save_to_disk(new_state)
    {:noreply, new_state}
  end

  defp load_from_disk(path) do
    path
    |> File.read!()
    |> Jason.decode!(keys: :strings)
  end

  defp save_to_disk(state) do
    File.write!(@filename, Jason.encode!(state, pretty: true))
    Utils.Log.log("PersistenceStats", "Saved stats to disk at #{@filename}", &Utils.Colors.with_yellow_and_underline/1)
  end
end
