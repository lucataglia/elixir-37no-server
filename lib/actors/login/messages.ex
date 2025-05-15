defmodule Actors.Login.Messages do
  @moduledoc """
  Actors.Login.Messages
  """

  def menu_invalid_input(data) do
    "Invalid input #{Utils.Colors.with_underline(data)}\n"
  end

  def menu_invalid_input_back(data) do
    "Invalid input #{Utils.Colors.with_underline(data)}.\n" <>
      "Type #{Utils.Colors.with_underline("exit")} to exit the game.\n"
  end

  def menu do
    "#{Utils.Colors.with_yellow("WELCOME")}" <>
      """

      a. Login
      b. Create your account

      """
  end

  def sign_in do
    "#{Utils.Colors.with_green("LOGIN")}\n" <>
      "Insert username and password and press enter (e.g 'Jeff 000000')\n\n" <>
      "Username: must be 3-10 characters long and contain only letters\n" <>
      "Password: must be 6 characters long and contain only numbers\n\n"
  end

  def sign_up do
    "#{Utils.Colors.with_magenta("CREATE YOUR ACCOUNT")}\n" <>
      "Insert username and password and press enter (e.g 'Jeff 000000')\n\n" <>
      "Username: must be 3-10 characters long and contain only letters\n" <>
      "Password: must be 6 characters long and contain only numbers\n\n"
  end

  def username_already_exist(name) do
    "Username #{name} is already taken ☹️\nPlease choose another one\n"
  end

  def wait_for_game_start() do
    "Wait for the game to start\nType #{Utils.Colors.with_underline("back")} if you want to opt_out"
  end

  def invalid_credentials(name, password) do
    "Invalid credentials: #{Utils.Colors.with_underline("#{name} #{password}")}\n"
  end

  def sign_in_invalid_input(data) do
    "Invalid input #{Utils.Colors.with_underline(data)}\nPlease insert username and password\n"
  end

  def sign_up_invalid_input(data) do
    "Invalid input #{Utils.Colors.with_underline(data)}\nPlease insert username and password\n"
  end
end
