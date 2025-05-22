defmodule Utils.Regex do
  @moduledoc """
  Utils.Regex
  """

  def check_is_valid_card_key(key) do
    case Enum.member?(
           [
             "4h",
             "5h",
             "6h",
             "7h",
             "jh",
             "qh",
             "kh",
             "ah",
             "2h",
             "3h",
             "4d",
             "5d",
             "6d",
             "7d",
             "jd",
             "qd",
             "kd",
             "ad",
             "2d",
             "3d",
             "4c",
             "5c",
             "6c",
             "7c",
             "jc",
             "qc",
             "kc",
             "ac",
             "2c",
             "3c",
             "4s",
             "5s",
             "6s",
             "7s",
             "js",
             "qs",
             "ks",
             "as",
             "2s",
             "3s"
           ],
           key
         ) do
      true -> :ok
      false -> {:error, :invalid_input}
    end
  end

  def check_end_game_input(recv) do
    case String.downcase(recv) do
      "share" ->
        {:share}

      "s" ->
        {:share}

      "replay" ->
        {:replay}

      "r" ->
        {:replay}

      _ ->
        {:error, :invalid_input}
    end
  end

  def check_end_game_input_ready_to_replay(recv) do
    case String.downcase(recv) do
      "share" ->
        {:share}

      "s" ->
        {:share}

      _ ->
        {:error, :invalid_input}
    end
  end

  def check_observe_a_player(recv) do
    cond do
      String.downcase(recv) =~ ~r/^observe [A-Za-z]{3,10}$/ ->
        [_, name] = String.split(recv, " ")
        {:ok, name}

      String.downcase(recv) =~ ~r/^obs [A-Za-z]{3,10}$/ ->
        [_, name] = String.split(recv, " ")
        {:ok, name}

      true ->
        {:error, :invalid_input}
    end
  end
end
