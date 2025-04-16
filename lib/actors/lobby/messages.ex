defmodule Actors.Lobby.Messages do
  @moduledoc """
  Actors.Lobby.Messages
  """

  def invalid_input_lobby(data) do
    "Invalid input #{Utils.Colors.with_underline(data)}"
  end

  def invalid_input_opted_in(data) do
    "Invalid input #{Utils.Colors.with_underline(data)}. Type #{Utils.Colors.with_underline("back")} to opt-out the game"
  end

  def user_already_opted_in(name) do
    "A user name with name #{Utils.Colors.with_underline(name)} already opted in for that game"
  end

  def lobby do
    "#{Utils.Colors.with_green("LOBBY")}" <> "\n" <> "Type #{Utils.Colors.with_underline("play")} to opt_in to a game\n"
  end

  def opted_in do
    "#{Utils.Colors.with_green("OPTED IN")}" <> "\n" <> "Type #{Utils.Colors.with_underline("back")} to opt_out the game\n"
  end

  def player_opt_out(players_name, name, count) do
    player_word = if count == 1, do: "player", else: "players"

    "#{name} opt_out 🚫\nPlayers: #{players_name}\nWaiting for other #{count} #{player_word}...\n"
  end

  def opt_out_success() do
    "You have successfully opted out of the game"
  end
end
