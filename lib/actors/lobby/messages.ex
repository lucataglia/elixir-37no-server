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

  def table_maanger_stopped_due_to_inactivity() do
    "Table closed due to inactivity"
  end

  def lobby(name) do
    stats =
      case Actors.Persistence.Stats.get_stats(name) do
        {:ok, s} -> s
        # this should never happen
        _ -> ""
      end

    Actors.Persistence.Stats.PrintUtils.pretty_print_stats(name, stats) <>
      "\n\n\n" <>
      Messages.print_summary_table() <>
      "\n\n\n" <>
      Messages.recap_sentence() <>
      "\n\n\n" <>
      "#{Utils.Colors.with_green("LOBBY")}" <> "\n" <> "Type #{Utils.Colors.with_underline("play")} to opt_in to a game\n"
  end

  def opted_in do
    Messages.print_summary_table() <>
      "\n\n\n" <>
      Messages.recap_sentence() <>
      "\n\n\n" <>
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
