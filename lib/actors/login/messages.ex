defmodule Actors.Login.Messages do
  def menu_invalid_input do
    "Invalid input\n"
  end

  def menu do
    "#{Utils.Colors.withYellow("WELCOME")}" <>
      """

      a. Login
      b. Create your account

      """
  end

  def sign_in do
    "#{Utils.Colors.withGreen("LOGIN")}" <> "\n" <> "Insert username and password and press enter e.g 'Jeff 000000'\n"
  end

  def sign_up do
    Utils.Colors.withMagenta("CREATE YOUR ACCOUNT") <> "\n" <> "Insert username and password and press enter e.g 'Jeff 000000'\n"
  end

  def username_already_exist(name) do
    "Username #{name} is already taken ☹️\nPlease choose another one\n"
  end

  def wait_for_game_start() do
    "Wait for the game to start\nType #{Utils.Colors.withUnderline("back")} if you want to opt_out"
  end

  def invalid_credentials() do
    "Invalid credentials\n"
  end
end
