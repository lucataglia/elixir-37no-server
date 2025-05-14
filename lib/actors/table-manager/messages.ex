defmodule Actors.NewTableManager.Messages do
  @moduledoc """
  Actors.TableManager.Messages
  """

  def player_left_the_game(name), do: "#{name} exit the game 🚫\n"

  def player_rejoined_the_game(name), do: "#{name} is back 💪 \n"

  def rejoin_success, do: "Welcome back 💪"

  def observe_success, do: "Welcome to the table as observer 👀"

  def observe_leave_error(name), do: "Player #{name} is not observing this table"

  def wants_to_replay(names) do
    case length(names) do
      1 -> "#{IO.ANSI.format([:cyan, Enum.join(names, "")])} is ready to play again"
      _ -> "#{IO.ANSI.format([:cyan, Enum.join(names, " and ")])} are ready to play again"
    end
  end

  def shared_cards(name, cards) do
    ordered_cards = Deck.print_card_in_order(cards, print_also_used_cards: true, print_also_high_cards_count: true)

    "#{name} shared his cards:\n" <>
      ordered_cards
  end
end
