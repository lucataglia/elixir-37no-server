defmodule Elixir37noServerTest do
  use ExUnit.Case
  doctest Elixir37noServer

  test "greets the world" do
    assert Elixir37noServer.hello() == :world
  end
end
