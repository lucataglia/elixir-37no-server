defmodule SimpleServer do
  def start(_, [port]) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Actors.TableManager.start_link()

    IO.puts("Server listening on port #{port}")
    accept_connections(socket)
  end

  defp accept_connections(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    IO.puts("Client connected")

    {:ok, pid} = Actors.Player.start_link(client)
    spawn(fn -> handle_client(client, pid) end)

    :gen_tcp.send(client, Messages.title())
    :gen_tcp.send(client, "Pick a name (only letters and numbers, no whitespaces): ")

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
                Actors.Player.stop(pid)

              no_white_spaces ->
                Actors.Player.forward_data(pid, no_white_spaces)
                handle_client(client, pid)
            end).()

      {:error, :closed} ->
        Actors.Player.stop(pid)
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
