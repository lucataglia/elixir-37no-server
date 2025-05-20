defmodule Actors.Player.Messages do
  @moduledoc """
  Actors.Player.Messages
  """

  def good_luck, do: "Good luck 🍀"

  def i_am_thinking_deeply(name), do: "#{name} 💬 I am thinking deeply..."

  def card_stashed(card), do: "#{card} stashed 👌"

  def my_cards_was(cards), do: "My cards:\n" <> cards

  def card_already_shared, do: "Card already shared!"
end
