defmodule Actors.Lobby.Messages do
  def invalid_input do
    "Invalid input\n"
  end

  def lobby do
    "#{Utils.Colors.withGreen("LOBBY")}" <> "\n" <> "Write 'play' to opt_in to a game\n"
  end
end
