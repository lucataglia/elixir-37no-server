defmodule Deck do
  # 1. comment factory
  # 2. change the chunk_every function arg
  # 3. change the 39 hardcoded into the table-manager
  def card_count do
    39
  end

  def chunk_size do
    13
  end

  def factory,
    do: %{
      # Hearts
      "4h": %{key: "4h", label: "Four of Hearts", suit: "hearts", pretty: "4 🔴️", ranking: 1, sort_id: 1, points: 0, used: false},
      "5h": %{key: "5h", label: "Five of Hearts", suit: "hearts", pretty: "5 🔴️", ranking: 2, sort_id: 2, points: 0, used: false},
      "6h": %{key: "6h", label: "Six of Hearts", suit: "hearts", pretty: "6 🔴️", ranking: 3, sort_id: 3, points: 0, used: false},
      "7h": %{key: "7h", label: "Seven of Hearts", suit: "hearts", pretty: "7 🔴️", ranking: 4, sort_id: 4, points: 0, used: false},
      jh: %{key: "jh", label: "Jack of Hearts", suit: "hearts", pretty: "J 🔴️", ranking: 5, sort_id: 5, points: 0.34, used: false},
      qh: %{key: "qh", label: "Queen of Hearts", suit: "hearts", pretty: "Q 🔴️", ranking: 6, sort_id: 6, points: 0.34, used: false},
      kh: %{key: "kh", label: "King of Hearts", suit: "hearts", pretty: "K 🔴️", ranking: 7, sort_id: 7, points: 0.34, used: false},
      ah: %{key: "ah", label: "Ace of Hearts", suit: "hearts", pretty: "A 🔴️", ranking: 8, sort_id: 8, points: 1, used: false},
      "2h": %{key: "2h", label: "Two of Hearts", suit: "hearts", pretty: "2 🔴️", ranking: 9, sort_id: 9, points: 0.34, used: false},
      "3h": %{key: "3h", label: "Three of Hearts", suit: "hearts", pretty: "3 🔴️", ranking: 10, sort_id: 10, points: 0.34, used: false},

      # Diamonds
      "4d": %{key: "4d", label: "Four of Diamonds", suit: "diamonds", pretty: "4 🔵", ranking: 1, sort_id: 11, points: 0, used: false},
      "5d": %{key: "5d", label: "Five of Diamonds", suit: "diamonds", pretty: "5 🔵", ranking: 2, sort_id: 12, points: 0, used: false},
      "6d": %{key: "6d", label: "Six of Diamonds", suit: "diamonds", pretty: "6 🔵", ranking: 3, sort_id: 13, points: 0, used: false},
      "7d": %{key: "7d", label: "Seven of Diamonds", suit: "diamonds", pretty: "7 🔵", ranking: 4, sort_id: 14, points: 0, used: false},
      jd: %{key: "jd", label: "Jack of Diamonds", suit: "diamonds", pretty: "J 🔵", ranking: 5, sort_id: 15, points: 0.34, used: false},
      qd: %{key: "qd", label: "Queen of Diamonds", suit: "diamonds", pretty: "Q 🔵", ranking: 6, sort_id: 16, points: 0.34, used: false},
      kd: %{key: "kd", label: "King of Diamonds", suit: "diamonds", pretty: "K 🔵", ranking: 7, sort_id: 17, points: 0.34, used: false},
      ad: %{key: "ad", label: "Ace of Diamonds", suit: "diamonds", pretty: "A 🔵", ranking: 8, sort_id: 18, points: 1, used: false},
      "2d": %{key: "2d", label: "Two of Diamonds", suit: "diamonds", pretty: "2 🔵", ranking: 9, sort_id: 19, points: 0.34, used: false},
      "3d": %{key: "3d", label: "Three of Diamonds", suit: "diamonds", pretty: "3 🔵", ranking: 10, sort_id: 20, points: 0.34, used: false},

      # Clubs
      "4c": %{key: "4c", label: "Four of Clubs", suit: "clubs", pretty: "4 🟢", ranking: 1, sort_id: 21, points: 0, used: false},
      "5c": %{key: "5c", label: "Five of Clubs", suit: "clubs", pretty: "5 🟢", ranking: 2, sort_id: 22, points: 0, used: false},
      "6c": %{key: "6c", label: "Six of Clubs", suit: "clubs", pretty: "6 🟢", ranking: 3, sort_id: 23, points: 0, used: false},
      "7c": %{key: "7c", label: "Seven of Clubs", suit: "clubs", pretty: "7 🟢", ranking: 4, sort_id: 24, points: 0, used: false},
      jc: %{key: "jc", label: "Jack of Clubs", suit: "clubs", pretty: "J 🟢", ranking: 5, sort_id: 25, points: 0.34, used: false},
      qc: %{key: "qc", label: "Queen of Clubs", suit: "clubs", pretty: "Q 🟢", ranking: 6, sort_id: 26, points: 0.34, used: false},
      kc: %{key: "kc", label: "King of Clubs", suit: "clubs", pretty: "K 🟢", ranking: 7, sort_id: 27, points: 0.34, used: false},
      ac: %{key: "ac", label: "Ace of Clubs", suit: "clubs", pretty: "A 🟢", ranking: 8, sort_id: 28, points: 1, used: false},
      "2c": %{key: "2c", label: "Two of Clubs", suit: "clubs", pretty: "2 🟢", ranking: 9, sort_id: 29, points: 0.34, used: false},
      "3c": %{key: "3c", label: "Three of Clubs", suit: "clubs", pretty: "3 🟢", ranking: 10, sort_id: 30, points: 0.34, used: false},

      # Spades
      # "4s": %{key: "4s", label: "Four of Spades", suit: "spades", pretty: "4 ⚫️", ranking: 1, sort_id: 31, points: 0, used: false},
      "5s": %{key: "5s", label: "Five of Spades", suit: "spades", pretty: "5 ⚫️", ranking: 2, sort_id: 32, points: 0, used: false},
      "6s": %{key: "6s", label: "Six of Spades", suit: "spades", pretty: "6 ⚫️", ranking: 3, sort_id: 33, points: 0, used: false},
      "7s": %{key: "7s", label: "Seven of Spades", suit: "spades", pretty: "7 ⚫️", ranking: 4, sort_id: 34, points: 0, used: false},
      js: %{key: "js", label: "Jack of Spades", suit: "spades", pretty: "J ⚫️", ranking: 5, sort_id: 35, points: 0.34, used: false},
      qs: %{key: "qs", label: "Queen of Spades", suit: "spades", pretty: "Q ⚫️", ranking: 6, sort_id: 36, points: 0.34, used: false},
      ks: %{key: "ks", label: "King of Spades", suit: "spades", pretty: "K ⚫️", ranking: 7, sort_id: 37, points: 0.34, used: false},
      as: %{key: "as", label: "Ace of Spades", suit: "spades", pretty: "A ⚫️", ranking: 8, sort_id: 38, points: 1, used: false},
      "2s": %{key: "2s", label: "Two of Spades", suit: "spades", pretty: "2 ⚫️", ranking: 9, sort_id: 39, points: 0.34, used: false},
      "3s": %{key: "3s", label: "Three of Spades", suit: "spades", pretty: "3 ⚫️", ranking: 10, sort_id: 40, points: 0.34, used: false}
    }

  def is_a_valid_card(key, cards, turn_first_card) do
    card = cards[String.to_atom(key)]

    if card do
      cond do
        turn_first_card[:suit] == nil ->
          # First card of the turn
          :ok

        card[:suit] == turn_first_card[:suit] ->
          # The card has the same suit of the first card of the turn
          :ok

        true ->
          other_card_with_same_suit_exist =
            cards
            |> Enum.to_list()
            |> Enum.filter(fn {_, %{used: u}} -> !u end)
            |> Enum.any?(fn {_, %{suit: suit}} -> suit == turn_first_card[:suit] end)

          if other_card_with_same_suit_exist do
            # The card has NOT the same suit of the first card of the turn AND I HAVE SOME CARDS LEFT WITH THAT SUIT
            {:error, :wrong_suit}
          else
            # The card has NOT the same suit of the first card of the turn but I can play the card I want
            {:ok, :change_ranking}
          end
      end
    else
      # INVALID CHARACTERS
      {:error, :invalid_input}
    end
  end

  def shuffle,
    do:
      factory()
      |> Map.drop([":4s"])
      |> Enum.to_list()
      |> Enum.shuffle()
      |> Enum.chunk_every(chunk_size())
end
