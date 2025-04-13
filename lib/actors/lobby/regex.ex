defmodule Actors.Lobby.Regex do
  def check_game_opt_in(str) do
    case str do
      "play" -> {:ok, :opt_in}
      "p" -> {:ok, :opt_in}
      _ -> {:error, :invalid_input}
    end
  end

  def check_game_opt_out(str) do
    case str do
      "back" ->
        {:ok, :opt_out}

      _ ->
        {:error, :invalid_input}
    end
  end
end
