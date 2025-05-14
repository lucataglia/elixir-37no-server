defmodule Actors.Player.Messages do
  @moduledoc """
  Actors.Player.Messages
  """

  def good_luck, do: "Good luck 🍀"

  def card_stashed(card), do: "#{card} stashed 👌"
  def card_shared, do: "Card shared 👌"
  def card_already_shared, do: "Card already shared!"
end
