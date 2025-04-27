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

  test "three clients connect and send commands in sequence with active true" do
    # Client 1: Send 'b'
    # {:ok, sock1} = TCP.connect(~c"localhost", @port, [:binary, buffer: 65_536, recbuf: 131_072, sndbuf: 131_072, active: true])
    {:ok, sock1} = TCP.connect(~c"localhost", @port, [:binary, buffer: 65_536, recbuf: 131_072, sndbuf: 131_072, active: true])
    {:ok, sock2} = TCP.connect(~c"localhost", @port, [:binary, active: false])
    {:ok, sock3} = TCP.connect(~c"localhost", @port, [:binary, active: false])

    pid = spawn_link(fn -> loop(sock1) end)

    TCP.controlling_process(sock1, pid)

    login_action(sock1)
    login_action(sock2)
    login_action(sock3)

    # Optionally wait for processing (if asynchronous)
    Process.sleep(100)

    create_user(sock1, "Jeff")
    create_user(sock2, "Joe")
    create_user(sock3, "TheFe")

    # Optionally wait for processing (if asynchronous)
    Process.sleep(100)

    play(sock1)
    play(sock3)
    play(sock2)

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
  defp play(socket), do: TCP.send(socket, "play\n")

  defp assert_response(socket, expected) do
    {:ok, data} = TCP.recv(socket, 0, 1000)
    assert data =~ expected
  end
end
