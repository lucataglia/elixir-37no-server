Code.require_file("player.exs")
Code.require_file("table-manager.exs")
Code.require_file("constants.exs")

defmodule SimpleServer do
  def start(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    IO.puts("Server listening on port #{port}")
    accept_connections(socket)
  end

  defp accept_connections(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    IO.puts("Client connected")
    {:ok, pid} = Player.start_link(client)
    spawn(fn -> handle_client(client, pid) end)

    :gen_tcp.send(client, Constants.title())
    :gen_tcp.send(client, "Inserisci il tuo nome: ")

    accept_connections(socket)
  end

  defp handle_client(client, pid) do
    case read_line(client) do
      {:ok, data} ->
        data
        |> String.replace(~r/\s+/, "")
        |> String.downcase()
        |> (fn
              "exit" ->
                IO.puts("Close the client")

                send(self(), :stop)
                :gen_tcp.close(client)
                Player.stop(pid)

              no_white_spaces ->
                Player.forward_data(pid, no_white_spaces)
            end).()

      {:error, :closed} ->
        IO.puts("Client disconnected")

      {:error, reason} ->
        IO.puts("Error: #{reason}")
    end

    receive do
      :stop ->
        IO.puts("Stopping the handle_client...")
        exit(:normal)

      _ ->
        # Ignore other messages for now
        IO.puts("Unknown message received")
    end
  end

  defp read_line(client) do
    :gen_tcp.recv(client, 0)
  end
end

TableManager.start_link()
SimpleServer.start(4000)
