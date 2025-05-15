defmodule MyApp.SocketTest do
  @moduledoc """
  SocketTest
  """

  use ExUnit.Case, async: false
  alias :gen_tcp, as: TCP

  @port 4000

  setup do
    # Start your application if not already running
    {:ok, _} = Application.ensure_all_started(:elixir_37no_server)
    :ok
  end

  # TODO:
  # We need to change the `players` and `deck` data structures from maps to keyword lists.
  # This is because keyword lists preserve the order of elements and allow duplicate keys,
  # which is important for maintaining the correct sequence and behavior in our game logic.
  # Unlike maps, keyword lists guarantee consistent iteration order, making them better suited
  # for scenarios where order matters (e.g., player turns, card order in the deck).
  #
  # Please update all relevant code to handle keyword lists accordingly.
  test "three clients connect and send commands in sequence with active true" do
    # {:ok, sock1} = TCP.connect(~c"localhost", @port, [:binary, buffer: 65_536, recbuf: 131_072, sndbuf: 131_072, active: true])
    {:ok, sock1} = TCP.connect(~c"localhost", @port, [:binary, buffer: 65_536, recbuf: 131_072, sndbuf: 131_072, active: true])
    {:ok, sock2} = TCP.connect(~c"localhost", @port, [:binary, buffer: 65_536, recbuf: 131_072, sndbuf: 131_072, active: true])
    {:ok, sock3} = TCP.connect(~c"localhost", @port, [:binary, buffer: 65_536, recbuf: 131_072, sndbuf: 131_072, active: true])

    pid = spawn_link(fn -> loop(sock3) end)

    TCP.controlling_process(sock3, pid)

    login_action(sock1)
    login_action(sock2)
    login_action(sock3)

    # Optionally wait for processing (if asynchronous)
    Process.sleep(100)

    create_user(sock1, "testjeff")
    create_user(sock2, "testjoebas")
    create_user(sock3, "testThe")

    # Optionally wait for processing (if asynchronous)
    Process.sleep(100)

    opt_in(sock1)
    opt_in(sock3)
    opt_in(sock2)

    # Optionally wait for processing (if asynchronous)
    Process.sleep(100)

    play_card(sock1, "4h")
    stash_card(sock3, "7h")
    play_card(sock2, "5h")

    play_card(sock3, "as")
    play_card(sock1, "3s")
    play_card(sock2, "ks")

    play_card(sock1, "jd")
    play_card(sock2, "ad")
    play_card(sock3, "kd")

    play_card(sock2, "7d")
    play_card(sock3, "3d")
    play_card(sock1, "6d")

    play_card(sock3, "qd")
    play_card(sock1, "4d")
    play_card(sock2, "5d")

    play_card(sock3, "2d")
    play_card(sock1, "ac")
    play_card(sock2, "jh")

    play_card(sock3, "5c")
    play_card(sock1, "3h")
    play_card(sock2, "7c")

    play_card(sock2, "5s")
    play_card(sock3, "3c")
    play_card(sock1, "6s")

    play_card(sock1, "7s")
    play_card(sock2, "2s")
    play_card(sock3, "2c")

    play_card(sock2, "4c")
    play_card(sock3, "kc")
    play_card(sock1, "2h")

    play_card(sock3, "ah")
    play_card(sock1, "kh")
    play_card(sock2, "qs")

    play_card(sock3, "qc")
    play_card(sock1, "qh")
    play_card(sock2, "6c")

    play_card(sock3, "jc")
    play_card(sock1, "6h")
    play_card(sock2, "js")

    share(sock1)
    auto_share(sock1)

    share(sock2)
    auto_share(sock2)

    share(sock3)
    auto_share(sock3)

    replay(sock1)
    replay(sock2)
    replay(sock3)

    play_card(sock2, "5h")
    stash_card(sock1, "4h")
    play_card(sock3, "7h")

    play_card(sock3, "as")
    play_card(sock1, "3s")
    play_card(sock2, "ks")

    play_card(sock1, "jd")
    play_card(sock2, "ad")
    play_card(sock3, "kd")

    play_card(sock2, "7d")
    play_card(sock3, "3d")
    play_card(sock1, "6d")

    play_card(sock3, "qd")
    play_card(sock1, "4d")
    play_card(sock2, "5d")

    play_card(sock3, "2d")
    play_card(sock1, "ac")
    play_card(sock2, "jh")

    play_card(sock3, "5c")
    play_card(sock1, "3h")
    play_card(sock2, "7c")

    play_card(sock2, "5s")
    play_card(sock3, "3c")
    play_card(sock1, "6s")

    play_card(sock1, "7s")
    play_card(sock2, "2s")
    play_card(sock3, "2c")

    play_card(sock2, "4c")
    play_card(sock3, "kc")
    play_card(sock1, "2h")

    play_card(sock3, "ah")
    play_card(sock1, "kh")
    play_card(sock2, "qs")

    play_card(sock3, "qc")
    play_card(sock1, "qh")
    play_card(sock2, "6c")

    play_card(sock3, "jc")
    play_card(sock1, "6h")
    play_card(sock2, "js")

    share(sock1)
    auto_share(sock1)

    share(sock2)
    auto_share(sock2)

    share(sock3)
    auto_share(sock3)

    replay(sock1)
    replay(sock2)
    replay(sock3)

    play_card(sock3, "7h")
    stash_card(sock2, "5h")
    play_card(sock1, "4h")

    play_card(sock3, "as")
    play_card(sock1, "3s")
    play_card(sock2, "ks")

    play_card(sock1, "jd")
    play_card(sock2, "ad")
    play_card(sock3, "kd")

    play_card(sock2, "7d")
    play_card(sock3, "3d")
    play_card(sock1, "6d")

    play_card(sock3, "qd")
    play_card(sock1, "4d")
    play_card(sock2, "5d")

    play_card(sock3, "2d")
    play_card(sock1, "ac")
    play_card(sock2, "jh")

    play_card(sock3, "5c")
    play_card(sock1, "3h")
    play_card(sock2, "7c")

    play_card(sock2, "5s")
    play_card(sock3, "3c")
    play_card(sock1, "6s")

    play_card(sock1, "7s")
    play_card(sock2, "2s")
    play_card(sock3, "2c")

    play_card(sock2, "4c")
    play_card(sock3, "kc")
    play_card(sock1, "2h")

    play_card(sock3, "ah")
    play_card(sock1, "kh")
    play_card(sock2, "qs")

    play_card(sock3, "qc")
    play_card(sock1, "qh")
    play_card(sock2, "6c")

    play_card(sock3, "jc")
    play_card(sock1, "6h")
    play_card(sock2, "js")

    share(sock1)
    auto_share(sock1)

    share(sock2)
    auto_share(sock2)

    share(sock3)
    auto_share(sock3)

    replay(sock1)
    replay(sock2)
    replay(sock3)

    play_card(sock1, "4h")
    stash_card(sock3, "7h")
    play_card(sock2, "5h")

    play_card(sock3, "as")
    play_card(sock1, "3s")
    play_card(sock2, "ks")

    play_card(sock1, "jd")
    play_card(sock2, "ad")
    play_card(sock3, "kd")

    play_card(sock2, "7d")
    play_card(sock3, "3d")
    play_card(sock1, "6d")

    play_card(sock3, "qd")
    play_card(sock1, "4d")
    play_card(sock2, "5d")

    play_card(sock3, "2d")
    play_card(sock1, "ac")
    play_card(sock2, "jh")

    play_card(sock3, "5c")
    play_card(sock1, "3h")
    play_card(sock2, "7c")

    play_card(sock2, "5s")
    play_card(sock3, "3c")
    play_card(sock1, "6s")

    play_card(sock1, "7s")
    play_card(sock2, "2s")
    play_card(sock3, "2c")

    play_card(sock2, "4c")
    play_card(sock3, "kc")
    play_card(sock1, "2h")

    play_card(sock3, "ah")
    play_card(sock1, "kh")
    play_card(sock2, "qs")

    play_card(sock3, "qc")
    play_card(sock1, "qh")
    play_card(sock2, "6c")

    play_card(sock3, "jc")
    play_card(sock1, "6h")
    play_card(sock2, "js")

    share(sock1)
    auto_share(sock1)

    share(sock2)
    auto_share(sock2)

    share(sock3)
    auto_share(sock3)

    replay(sock1)
    replay(sock2)
    replay(sock3)

    exit_fn(sock2)
    # Optionally wait for processing (if asynchronous)
    Process.sleep(2000)

    # Add assertions here based on expected server responses
    # Example: assert_response(sock1, "Welcome message")

    # Cleanup
    TCP.close(sock1)
    TCP.close(sock2)
    TCP.close(sock3)
  end

  defp loop(socket) do
    receive do
      {:tcp, ^socket, data} ->
        IO.puts(data)
        loop(socket)

      {:tcp_closed, ^socket} ->
        IO.puts("Connection closed")
        :ok

      {:tcp_error, ^socket, reason} ->
        IO.puts("TCP error: #{inspect(reason)}")
        :error

      other ->
        # Optionally ignore other messages or print for debugging
        IO.puts(other <> ": sock1 unexpected message")
        loop(socket)
    end
  end

  defp login_action(socket), do: TCP.send(socket, "b\n")
  defp create_user(socket, name), do: TCP.send(socket, "#{name} 000000\n")
  defp opt_in(socket), do: TCP.send(socket, "play\n")

  defp play_card(socket, card) do
    TCP.send(socket, "#{card}\n")
    Process.sleep(10)
  end

  defp stash_card(socket, card) do
    TCP.send(socket, "#{card}\n")
    Process.sleep(10)
  end

  defp replay(socket) do
    TCP.send(socket, "replay\n")
    Process.sleep(10)
  end

  defp share(socket) do
    TCP.send(socket, "share\n")
    Process.sleep(10)
  end

  defp auto_share(socket) do
    TCP.send(socket, "auto share\n")
    Process.sleep(10)
  end

  defp exit_fn(socket) do
    TCP.send(socket, "exit\n")
    Process.sleep(10)
  end

  defp assert_response(socket, expected) do
    {:ok, data} = TCP.recv(socket, 0, 1000)
    assert data =~ expected
  end
end

# pretty: "4 🔴️", --
# pretty: "6 🔴️", --
# pretty: "Q 🔴️", --
# pretty: "K 🔴️", --
# pretty: "2 🔴️", --
# pretty: "3 🔴️", --
# pretty: "4 🔵", --
# pretty: "6 🔵", --
# pretty: "J 🔵", --
# pretty: "A 🟢", --
# pretty: "6 ⚫️", --
# pretty: "7 ⚫️", --
# pretty: "3 ⚫️", --
#
# pretty: "5 🔴️", --
# pretty: "J 🔴️", --
# pretty: "5 🔵", --
# pretty: "7 🔵", --
# pretty: "A 🔵", --
# pretty: "4 🟢", --
# pretty: "6 🟢", --
# pretty: "7 🟢", --
# pretty: "5 ⚫️", --
# pretty: "J ⚫️", --
# pretty: "Q ⚫️", --
# pretty: "K ⚫️", --
# pretty: "2 ⚫️", --
#
# pretty: "7 🔴️", --
# pretty: "A 🔴️", --
# pretty: "Q 🔵", --
# pretty: "K 🔵", --
# pretty: "2 🔵", --
# pretty: "3 🔵", --
# pretty: "5 🟢", --
# pretty: "J 🟢", --
# pretty: "Q 🟢", --
# pretty: "K 🟢", --
# pretty: "2 🟢", --
# pretty: "3 🟢", --
# pretty: "A ⚫️", --
