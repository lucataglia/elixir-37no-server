defmodule Actors.Login.Regex do
  @moduledoc """
  Actors.Login.Regex
  """

  def check_menu_input(str) do
    case str do
      "a" -> {:ok, :sign_in}
      "b" -> {:ok, :sign_up}
      "back" -> {:error, :invalid_input_back}
      _ -> {:error, :invalid_input}
    end
  end

  def check_username_and_password(str) do
    cond do
      str =~ ~r/^[A-Za-z]{3,10} \d{6}$/ ->
        [name, password] = String.split(str, " ")
        {:ok, name, password}

      str == "back" ->
        {:ok, :back}

      true ->
        {:error, :invalid_input}
    end
  end
end
