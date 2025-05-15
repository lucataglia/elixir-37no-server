defmodule Actors.Stats do
  @moduledoc """
    Stats
  """
  alias Utils.Colors
  use GenServer

  @filename "user_stats.json"

  # Define all GenServer messages as module attributes
  @record_game :record_game
  @get_stats :get_stats

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_stats(username) do
    GenServer.call(__MODULE__, {@get_stats, username})
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
    log("Using stats file at: #{full_path}")

    state =
      case File.exists?(full_path) do
        true ->
          log("Loading stats from existing file.")
          load_from_disk(full_path)

        false ->
          log("Stats file not found. Creating new file with empty state.")
          File.write!(full_path, Jason.encode!(%{}))
          %{}
      end

    {:ok, state}
  end

  @impl true
  def handle_call({@get_stats, username}, _from, state) do
    stats = Map.get(state, username, %{played: 0, won: 0, last_game_desc: "None"})
    log("Retrieved stats for user #{Colors.with_underline(username)}: #{inspect(stats)}")

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_cast({@record_game, username, players}, state) do
    [{first_name, %{leaderboard: leaderboard_first}}, {second_name, %{leaderboard: leaderboard_second}}, {third_name, %{leaderboard: leaderboard_third}}] =
      players |> Enum.sort_by(fn {_, %{leaderboard: l}} -> Enum.sum(l) end)

    final_points_first = leaderboard_first |> Enum.sum()
    final_points_second = leaderboard_second |> Enum.sum()
    final_points_third = leaderboard_third |> Enum.sum()

    won = first_name == username

    log("Recording game for user #{Colors.with_underline(username)}, won: #{won}")
    log_debug("last_game_desc: #{first_name}: #{final_points_first} - #{second_name}: #{final_points_second} - #{third_name}: #{final_points_third}")

    new_state =
      Map.update(state, username, %{"played" => 1, "won" => if(won, do: 1, else: 0)}, fn user_stats ->
        %{
          "played" => user_stats["played"] + 1,
          "won" => user_stats["won"] + if(won, do: 1, else: 0),
          "last_game_desc" => "#{first_name}: #{final_points_first} - #{second_name}: #{final_points_second} - #{third_name}: #{final_points_third}"
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
    File.write!(@filename, Jason.encode!(state))
    log("Saved stats to disk at #{@filename}")
  end

  # *** private api
  defp log(msg) do
    IO.puts("#{Colors.with_yellow_and_underline("Stats")} #{msg}")
  end

  defp log_debug(msg) do
    IO.puts("#{Colors.with_red_bright("Stats (DEBUG)")} #{msg}")
  end
end
