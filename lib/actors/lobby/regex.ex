defmodule Actors.Lobby.Regex do
  @moduledoc """
  Actors.Lobby.Regex
  """

  def check_game_opt_in(str) do
    cond do
      str =~ ~r/^rejoin\s[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i ->
        [_, uuid] = String.split(str, " ")
        {:ok, :rejoin, uuid}

      str =~ ~r/^r\s[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i ->
        [_, uuid] = String.split(str, " ")
        {:ok, :rejoin, uuid}

      str =~ ~r/^observe\s[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i ->
        [_, uuid] = String.split(str, " ")
        {:ok, :observe, uuid}

      str =~ ~r/^o\s[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i ->
        [_, uuid] = String.split(str, " ")
        {:ok, :observe, uuid}

      true ->
        case str do
          "observe tables" -> {:ok, :list_all_open_tables}
          "obs" -> {:ok, :list_all_open_tables}
          "open tables" -> {:ok, :list_my_open_tables}
          "ot" -> {:ok, :list_my_open_tables}
          "play" -> {:ok, :opt_in}
          "p" -> {:ok, :opt_in}
          "back" -> {:ok, :back}
          _ -> {:error, :invalid_input}
        end
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
