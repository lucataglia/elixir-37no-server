defmodule Deck do
  def factory,
    do: %{
      # Hearts
      "4h": {"Four of Hearts", 1, 0},
      "5h": {"Five of Hearts", 2, 0},
      "6h": {"Six of Hearts", 3, 0},
      "7h": {"Seven of Hearts", 4, 0},
      Jh: {"Jack of Hearts", 5, 0.3},
      Qh: {"Queen of Hearts", 6, 0.3},
      Kh: {"King of Hearts", 7, 0.3},
      Ah: {"Ace of Hearts", 8, 1},
      "2h": {"Two of Hearts", 9, 0.3},
      "3h": {"Three of Hearts", 10, 0.3},

      # Diamonds
      "4d": {"Four of Diamonds", 1, 0},
      "5d": {"Five of Diamonds", 2, 0},
      "6d": {"Six of Diamonds", 3, 0},
      "7d": {"Seven of Diamonds", 4, 0},
      Jd: {"Jack of Diamonds", 5, 0.3},
      Qd: {"Queen of Diamonds", 6, 0.3},
      Kd: {"King of Diamonds", 7, 0.3},
      Ad: {"Ace of Diamonds", 8, 1},
      "2d": {"Two of Diamonds", 9, 0.3},
      "3d": {"Three of Diamonds", 10, 0.3},

      # Clubs
      "4c": {"Four of Clubs", 1, 0},
      "5c": {"Five of Clubs", 2, 0},
      "6c": {"Six of Clubs", 3, 0},
      "7c": {"Seven of Clubs", 4, 0},
      Jc: {"Jack of Clubs", 5, 0.3},
      Qc: {"Queen of Clubs", 6, 0.3},
      Kc: {"King of Clubs", 7, 0.3},
      Ac: {"Ace of Clubs", 8, 1},
      "2c": {"Two of Clubs", 9, 0.3},
      "3c": {"Three of Clubs", 10, 0.3},

      # Spades
      # "4s": {"Four of Spades", 1, 0},
      "5s": {"Five of Spades", 2, 0},
      "6s": {"Six of Spades", 3, 0},
      "7s": {"Seven of Spades", 4, 0},
      Js: {"Jack of Spades", 5, 0.3},
      Qs: {"Queen of Spades", 6, 0.3},
      Ks: {"King of Spades", 7, 0.3},
      As: {"Ace of Spades", 8, 1},
      "2s": {"Two of Spades", 9, 0.3},
      "3s": {"Three of Spades", 10, 0.3}
    }

  def shuffle,
    do:
      factory()
      |> Map.drop([":4s"])
      |> Enum.to_list()
      |> Enum.shuffle()
      |> Enum.chunk_every(13)
end
