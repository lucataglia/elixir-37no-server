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
    {:ok, sock4} = TCP.connect(~c"localhost", @port, [:binary, buffer: 65_536, recbuf: 131_072, sndbuf: 131_072, active: true])
    {:ok, sock5} = TCP.connect(~c"localhost", @port, [:binary, buffer: 65_536, recbuf: 131_072, sndbuf: 131_072, active: true])

    pid = spawn_link(fn -> loop(sock3) end)

    TCP.controlling_process(sock3, pid)

    sign_in(sock1)
    sign_in(sock2)
    sign_in(sock3)
    sign_in(sock4)
    sign_up(sock5)

    # Optionally wait for processing (if asynchronous)
    Process.sleep(100)

    insert_credentials(sock1, "testjeff")
    insert_credentials(sock2, "testjoebas")
    insert_credentials(sock3, "testThe")
    insert_credentials(sock4, "testObs")
    insert_credentials(sock5, "testObsTwo")

    # Optionally wait for processing (if asynchronous)
    Process.sleep(100)

    opt_in(sock1)
    opt_in(sock3)
    opt_in(sock2)

    # # Optionally wait for processing (if asynchronous)
    Process.sleep(100)

    all_open_tables(sock4)
    observe_table(sock4, "123e4567-e89b-4a3c-8f12-123456789abc")

    play_card(sock3, "7h")
    play_card_really_fast(sock1, "4h")
    play_card_really_fast(sock1, "4h")
    play_card_really_fast(sock1, "4h")
    play_card_really_fast(sock1, "4h")
    play_card_really_fast(sock1, "4h")
    stash_card(sock3, "7h")
    play_card(sock2, "5h")

    # # testjeff accept a user that does not exist
    accept_to_be_observed(sock1, "testnotex")

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

    observe_player(sock4, "testnotex")
    observe_player(sock4, "testjeff")
    observe_player(sock4, "testjeff")

    play_card(sock3, "2d")
    play_card(sock1, "ac")
    play_card(sock2, "jh")

    play_card(sock3, "5c")
    play_card(sock1, "3h")
    play_card(sock2, "7c")

    # testjeff accept a user that does not exist
    accept_to_be_observed(sock1, "testnotex")

    # testjeff reject a testobs
    reject_to_be_observed(sock1, "testObs")

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

    observe_player(sock4, "testThe")

    play_card(sock3, "qc")
    play_card(sock1, "qh")
    play_card(sock2, "6c")

    # testThe accept a testObs
    accept_to_be_observed(sock3, "testObs")

    play_card(sock3, "jc")
    play_card(sock1, "6h")
    play_card(sock2, "js")

    share(sock1)
    share(sock2)
    share(sock3)

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
    share(sock2)
    share(sock3)

    replay(sock1)
    replay(sock2)
    replay(sock3)

    reject_to_be_observed(sock3, "testObs")

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
    share(sock2)
    share(sock3)

    replay(sock1)
    replay(sock2)
    replay(sock3)

    back(sock4)

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
    share(sock2)
    share(sock3)

    replay(sock1)
    replay(sock2)
    replay(sock3)

    back(sock2)
    open_tables(sock2)

    back(sock1)
    # exit_fn(sock2)
    # Optionally wait for processing (if asynchronous)
    Process.sleep(3000)

    opt_in(sock1)
    opt_in(sock2)
    opt_in(sock4)

    # # Optionally wait for processing (if asynchronous)
    Process.sleep(100)

    all_open_tables(sock3)
    all_open_tables(sock5)
    observe_table(sock3, "123e4567-e89b-4a3c-8f12-123456789abc")
    observe_table(sock5, "123e4567-e89b-4a3c-8f12-123456789abc")

    play_card(sock4, "7h")
    play_card(sock1, "4h")
    stash_card(sock4, "7h")
    play_card(sock2, "5h")

    play_card(sock4, "as")
    play_card(sock1, "3s")
    play_card(sock2, "ks")

    observe_player(sock3, "testnoex")
    observe_player(sock3, "testobs")
    observe_player(sock5, "testobs")

    play_card(sock1, "jd")
    play_card(sock2, "ad")
    play_card(sock4, "kd")

    play_card(sock2, "7d")
    play_card(sock4, "3d")
    play_card(sock1, "6d")

    play_card(sock4, "qd")
    play_card(sock1, "4d")
    play_card(sock2, "5d")

    accept_to_be_observed(sock4, "testnoex")
    accept_to_be_observed(sock4, "testthe")
    accept_to_be_observed(sock4, "testObsTwo")

    play_card(sock4, "2d")
    play_card(sock1, "ac")
    play_card(sock2, "jh")

    play_card(sock4, "5c")
    play_card(sock1, "3h")
    play_card(sock2, "7c")

    play_card(sock2, "5s")
    play_card(sock4, "3c")
    play_card(sock1, "6s")

    play_card(sock1, "7s")
    play_card(sock2, "2s")
    play_card(sock4, "2c")

    play_card(sock2, "4c")
    play_card(sock4, "kc")
    play_card(sock1, "2h")

    play_card(sock4, "ah")
    play_card(sock1, "kh")
    play_card(sock2, "qs")

    play_card(sock4, "qc")
    play_card(sock1, "qh")
    play_card(sock2, "6c")

    play_card(sock4, "jc")
    play_card(sock1, "6h")
    play_card(sock2, "js")

    share(sock1)
    share(sock2)
    share(sock4)

    replay(sock1)
    replay(sock2)

    Process.sleep(3000)

    IO.puts(" - - - > TEST END < - - - ")
    # Add assertions here based on expected server responses
    # Example: assert_response(sock1, "Welcome message")

    # Cleanup
    TCP.close(sock1)
    TCP.close(sock2)
    TCP.close(sock3)
    TCP.close(sock4)
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

  defp sign_up(socket), do: TCP.send(socket, "b\n")
  defp sign_in(socket), do: TCP.send(socket, "a\n")

  defp insert_credentials(socket, name) do
    TCP.send(socket, "#{name} 000000\n")
    Process.sleep(300)
  end

  defp opt_in(socket), do: TCP.send(socket, "play\n")
  defp open_tables(socket), do: TCP.send(socket, "ot\n")
  defp all_open_tables(socket), do: TCP.send(socket, "obs\n")
  defp observe_table(socket, uuid), do: TCP.send(socket, "observe #{uuid}\n")
  defp observe_player(socket, name), do: TCP.send(socket, "observe #{name}\n")
  defp accept_to_be_observed(socket, observer), do: TCP.send(socket, "obs yes #{observer}\n")
  defp reject_to_be_observed(socket, observer), do: TCP.send(socket, "obs no #{observer}\n")

  defp play_card_really_fast(socket, card) do
    TCP.send(socket, "#{card}\n")
  end

  defp play_card(socket, card) do
    TCP.send(socket, "#{card}\n")
    Process.sleep(15)
  end

  defp stash_card(socket, card) do
    TCP.send(socket, "#{card}\n")
    Process.sleep(15)
  end

  defp replay(socket) do
    TCP.send(socket, "replay\n")
    Process.sleep(15)
  end

  defp share(socket) do
    TCP.send(socket, "share\n")
    Process.sleep(15)
  end

  defp exit_fn(socket) do
    TCP.send(socket, "exit\n")
    Process.sleep(15)
  end

  defp back(socket) do
    TCP.send(socket, "back\n")
    Process.sleep(15)
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
