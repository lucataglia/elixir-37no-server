defmodule Actors.Login.Messages do
  def menu_invalid_input do
    "Invalid input"
  end

  def menu do
    """
    WELCCOME
    a. Login
    b. Create your account
    """
  end

  def sign_in do
    "\n#{Utils.Colors.withGreen("LOGIN")}" <> "\n" <> "Insert username and password and press enter e.g 'Jeff 000000'"
  end

  def sign_up do
    Utils.Colors.withMagenta("CREATE YOUR ACCOUNT") <> "\n" <> "Insert username and password and press enter e.g 'Jeff 000000'"
  end
end
