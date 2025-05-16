defmodule SimpleServer do
  @moduledoc """
  SimpleServer
  """

  def start(_, [port]) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, ip: {0, 0, 0, 0}, reuseaddr: true, keepalive: true])

    Actors.Persistence.Auth.start_link()
    Actors.Persistence.Stats.start_link()
    Actors.GameManager.start_link()

    IO.puts("SimpleServer: Server listening on port #{port}")
    accept_connections(socket)
  end

  defp accept_connections(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    # Enable keepalive on accepted client socket
    :ok = :inet.setopts(client, keepalive: true)

    IO.puts("SimpleServer: Client connected")

    {:ok, pid} = Actors.Bridge.start_link(client)
    spawn(fn -> handle_client(client, pid) end)

    accept_connections(socket)
  end

  defp handle_client(client, pid) do
    case read_line(client) do
      {:ok, data} ->
        data
        |> String.trim()
        |> String.downcase()
        |> (fn
              "exit" ->
                IO.puts("SimpleServer: Close the client - exit")

                send(self(), :stop)
                :gen_tcp.close(client)
                Actors.Bridge.exit(pid)

              no_white_spaces ->
                Actors.Bridge.forward_data(pid, no_white_spaces)
                handle_client(client, pid)
            end).()

      {:error, :closed} ->
        Actors.Bridge.client_disconected(pid)
        IO.puts("SimpleServer: Client disconnected")

      {:error, reason} ->
        IO.puts("SimpleServer: Error - #{reason}")
    end

    receive do
      :stop ->
        IO.puts("SimpleServer: Stopping the handle_client...")
        exit(:normal)

      _ ->
        # Ignore other messages for now
        IO.puts("SimpleServer: Unknown message received")
    end
  end

  defp read_line(client) do
    :gen_tcp.recv(client, 0)
  end
end
