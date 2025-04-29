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

  def chunked_deck() do
    [
      [
        "6s": %{
          label: "Six of Spades",
          used: false,
          key: "6s",
          pretty: "6 ⚫️",
          points: 0,
          sort_id: 33,
          suit: "spades",
          ranking: 3
        },
        "7s": %{
          label: "Seven of Spades",
          used: false,
          key: "7s",
          pretty: "7 ⚫️",
          points: 0,
          sort_id: 34,
          suit: "spades",
          ranking: 4
        },
        ac: %{
          label: "Ace of Clubs",
          used: false,
          key: "ac",
          pretty: "A 🟢",
          points: 1,
          sort_id: 28,
          suit: "clubs",
          ranking: 8
        },
        "2h": %{
          label: "Two of Hearts",
          used: false,
          key: "2h",
          pretty: "2 🔴️",
          points: 0.34,
          sort_id: 9,
          suit: "hearts",
          ranking: 9
        },
        qh: %{
          label: "Queen of Hearts",
          used: false,
          key: "qh",
          pretty: "Q 🔴️",
          points: 0.34,
          sort_id: 6,
          suit: "hearts",
          ranking: 6
        },
        "4d": %{
          label: "Four of Diamonds",
          used: false,
          key: "4d",
          pretty: "4 🔵",
          points: 0,
          sort_id: 11,
          suit: "diamonds",
          ranking: 1
        },
        "3s": %{
          label: "Three of Spades",
          used: false,
          key: "3s",
          pretty: "3 ⚫️",
          points: 0.34,
          sort_id: 40,
          suit: "spades",
          ranking: 10
        },
        kh: %{
          label: "King of Hearts",
          used: false,
          key: "kh",
          pretty: "K 🔴️",
          points: 0.34,
          sort_id: 7,
          suit: "hearts",
          ranking: 7
        },
        "3h": %{
          label: "Three of Hearts",
          used: false,
          key: "3h",
          pretty: "3 🔴️",
          points: 0.34,
          sort_id: 10,
          suit: "hearts",
          ranking: 10
        },
        jd: %{
          label: "Jack of Diamonds",
          used: false,
          key: "jd",
          pretty: "J 🔵",
          points: 0.34,
          sort_id: 15,
          suit: "diamonds",
          ranking: 5
        },
        "6d": %{
          label: "Six of Diamonds",
          used: false,
          key: "6d",
          pretty: "6 🔵",
          points: 0,
          sort_id: 13,
          suit: "diamonds",
          ranking: 3
        },
        "4h": %{
          label: "Four of Hearts",
          used: false,
          key: "4h",
          pretty: "4 🔴️",
          points: 0,
          sort_id: 1,
          suit: "hearts",
          ranking: 1
        },
        "6h": %{
          label: "Six of Hearts",
          used: false,
          key: "6h",
          pretty: "6 🔴️",
          points: 0,
          sort_id: 3,
          suit: "hearts",
          ranking: 3
        }
      ],
      [
        "7c": %{
          label: "Seven of Clubs",
          used: false,
          key: "7c",
          pretty: "7 🟢",
          points: 0,
          sort_id: 24,
          suit: "clubs",
          ranking: 4
        },
        "6c": %{
          label: "Six of Clubs",
          used: false,
          key: "6c",
          pretty: "6 🟢",
          points: 0,
          sort_id: 23,
          suit: "clubs",
          ranking: 3
        },
        ad: %{
          label: "Ace of Diamonds",
          used: false,
          key: "ad",
          pretty: "A 🔵",
          points: 1,
          sort_id: 18,
          suit: "diamonds",
          ranking: 8
        },
        "7d": %{
          label: "Seven of Diamonds",
          used: false,
          key: "7d",
          pretty: "7 🔵",
          points: 0,
          sort_id: 14,
          suit: "diamonds",
          ranking: 4
        },
        qs: %{
          label: "Queen of Spades",
          used: false,
          key: "qs",
          pretty: "Q ⚫️",
          points: 0.34,
          sort_id: 36,
          suit: "spades",
          ranking: 6
        },
        "2s": %{
          label: "Two of Spades",
          used: false,
          key: "2s",
          pretty: "2 ⚫️",
          points: 0.34,
          sort_id: 39,
          suit: "spades",
          ranking: 9
        },
        "5h": %{
          label: "Five of Hearts",
          used: false,
          key: "5h",
          pretty: "5 🔴️",
          points: 0,
          sort_id: 2,
          suit: "hearts",
          ranking: 2
        },
        "4c": %{
          label: "Four of Clubs",
          used: false,
          key: "4c",
          pretty: "4 🟢",
          points: 0,
          sort_id: 21,
          suit: "clubs",
          ranking: 1
        },
        js: %{
          label: "Jack of Spades",
          used: false,
          key: "js",
          pretty: "J ⚫️",
          points: 0.34,
          sort_id: 35,
          suit: "spades",
          ranking: 5
        },
        ks: %{
          label: "King of Spades",
          used: false,
          key: "ks",
          pretty: "K ⚫️",
          points: 0.34,
          sort_id: 37,
          suit: "spades",
          ranking: 7
        },
        jh: %{
          label: "Jack of Hearts",
          used: false,
          key: "jh",
          pretty: "J 🔴️",
          points: 0.34,
          sort_id: 5,
          suit: "hearts",
          ranking: 5
        },
        "5s": %{
          label: "Five of Spades",
          used: false,
          key: "5s",
          pretty: "5 ⚫️",
          points: 0,
          sort_id: 32,
          suit: "spades",
          ranking: 2
        },
        "5d": %{
          label: "Five of Diamonds",
          used: false,
          key: "5d",
          pretty: "5 🔵",
          points: 0,
          sort_id: 12,
          suit: "diamonds",
          ranking: 2
        }
      ],
      [
        "7h": %{
          label: "Seven of Hearts",
          used: false,
          key: "7h",
          pretty: "7 🔴️",
          points: 0,
          sort_id: 4,
          suit: "hearts",
          ranking: 4
        },
        as: %{
          label: "Ace of Spades",
          used: false,
          key: "as",
          pretty: "A ⚫️",
          points: 1,
          sort_id: 38,
          suit: "spades",
          ranking: 8
        },
        "3c": %{
          label: "Three of Clubs",
          used: false,
          key: "3c",
          pretty: "3 🟢",
          points: 0.34,
          sort_id: 30,
          suit: "clubs",
          ranking: 10
        },
        ah: %{
          label: "Ace of Hearts",
          used: false,
          key: "ah",
          pretty: "A 🔴️",
          points: 1,
          sort_id: 8,
          suit: "hearts",
          ranking: 8
        },
        kc: %{
          label: "King of Clubs",
          used: false,
          key: "kc",
          pretty: "K 🟢",
          points: 0.34,
          sort_id: 27,
          suit: "clubs",
          ranking: 7
        },
        kd: %{
          label: "King of Diamonds",
          used: false,
          key: "kd",
          pretty: "K 🔵",
          points: 0.34,
          sort_id: 17,
          suit: "diamonds",
          ranking: 7
        },
        "2c": %{
          label: "Two of Clubs",
          used: false,
          key: "2c",
          pretty: "2 🟢",
          points: 0.34,
          sort_id: 29,
          suit: "clubs",
          ranking: 9
        },
        "5c": %{
          label: "Five of Clubs",
          used: false,
          key: "5c",
          pretty: "5 🟢",
          points: 0,
          sort_id: 22,
          suit: "clubs",
          ranking: 2
        },
        qc: %{
          label: "Queen of Clubs",
          used: false,
          key: "qc",
          pretty: "Q 🟢",
          points: 0.34,
          sort_id: 26,
          suit: "clubs",
          ranking: 6
        },
        "3d": %{
          label: "Three of Diamonds",
          used: false,
          key: "3d",
          pretty: "3 🔵",
          points: 0.34,
          sort_id: 20,
          suit: "diamonds",
          ranking: 10
        },
        qd: %{
          label: "Queen of Diamonds",
          used: false,
          key: "qd",
          pretty: "Q 🔵",
          points: 0.34,
          sort_id: 16,
          suit: "diamonds",
          ranking: 6
        },
        "2d": %{
          label: "Two of Diamonds",
          used: false,
          key: "2d",
          pretty: "2 🔵",
          points: 0.34,
          sort_id: 19,
          suit: "diamonds",
          ranking: 9
        },
        jc: %{
          label: "Jack of Clubs",
          used: false,
          key: "jc",
          pretty: "J 🟢",
          points: 0.34,
          sort_id: 25,
          suit: "clubs",
          ranking: 5
        }
      ]
    ]
  end
end
