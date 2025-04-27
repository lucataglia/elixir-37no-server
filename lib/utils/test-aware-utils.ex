defmodule Utils.TestAware do
  @moduledoc """
  Utils.TestAware
  """

  @doc """
  Shuffles the list of `players` unless running inside a test environment.

  This function inspects the command-line arguments (`System.argv/0`) to determine
  whether the application is running in test mode. The convention used here is:

  - If `System.argv()` returns an empty list (`[]`), it indicates the app is **not**
    running with command-line arguments, which is assumed to mean **not in test mode**.
    In this case, the function returns a shuffled version of `players`.

  - If `System.argv()` returns a non-empty list, it is assumed the app is running
    with arguments (e.g., during tests), and the function returns the `players`
    list unchanged (no shuffle).

  The `_t` suffix in the function name denotes that this function's behavior depends
  on the test environment detection via command-line arguments.

  ## Parameters

  - `players` - a list of players to be shuffled or returned as-is.

  ## Returns

  - A shuffled list of players if not running in test mode.
  - The original list of players if running in test mode.

  ## Examples

      iex> shuffle_t([1, 2, 3])
      # When not running tests (System.argv() == []), returns a shuffled list like [3, 1, 2]

      iex> System.put_env("MIX_ENV", "test")
      iex> shuffle_t([1, 2, 3])
      # When running tests (System.argv() != []), returns [1, 2, 3] unchanged

  """
  def shuffle(players) do
    case System.argv() do
      [] -> Enum.shuffle(players)
      _ -> players
    end
  end
end
