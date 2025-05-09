defmodule Actors.Player.Messages do
  @moduledoc """
  Actors.Player.Messages
  """

  def good_luck, do: "Good luck 🍀"

  def timer_left(name, left), do: "#{name} has #{left * 30} seconds left"
end
