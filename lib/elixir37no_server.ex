defmodule SimpleServer do
  @moduledoc """
  SimpleServer
  """

  def start(_, [port]) do
    certfile = "./server.crt"
    keyfile = "./server.key"

    ssl_options = [
      certfile: certfile,
      keyfile: keyfile,
      # Optional: specify SSL versions and ciphers for security
      versions: [:"tlsv1.2", :"tlsv1.3"],
      reuse_sessions: true,
      # For testing; in production, use :verify_peer and CA certs
      verify: :verify_none
      # You can add more options as needed
    ]

    case :ssl.listen(port, [:binary, packet: :line, active: false, reuseaddr: true, keepalive: true] ++ ssl_options) do
      {:ok, socket} ->
        Actors.Persistence.Auth.start_link()
        Actors.Persistence.Stats.start_link()
        Actors.GameManager.start_link()

        Utils.Log.log("SimpleServer", "SSL Server listening on port #{port}", &Utils.NewColors.with_bg_yellow/1)
        accept_connections(socket)

      {:error, reason} ->
        Utils.Log.log("SimpleServer", "Failed to start server on port #{port} - #{reason}", &Utils.NewColors.with_bg_yellow/1)
        # Explicitly return an error tuple
        {:error, reason}
    end
  end

  defp accept_connections(socket) do
    case :ssl.transport_accept(socket) do
      {:ok, client} ->
        case :ssl.handshake(client) do
          {:ok, ssl_client} ->
            :ssl.setopts(ssl_client, keepalive: true)

            Utils.Log.log("SimpleServer", "SSL Client connected", &Utils.NewColors.with_bg_yellow/1)

            {:ok, pid} = Actors.Bridge.start_link(ssl_client)
            spawn(fn -> handle_client(ssl_client, pid) end)

            accept_connections(socket)

          {:error, reason} ->
            Utils.Log.log("SimpleServer", "SSL handshake failed - #{inspect(reason)}", &Utils.NewColors.with_bg_yellow/1)
            :ssl.close(client)
            accept_connections(socket)
        end

      {:error, :closed} ->
        Utils.Log.log("SimpleServer", "Listener socket closed, stopping accept loop", &Utils.NewColors.with_bg_yellow/1)
        :ok

      {:error, reason} ->
        Utils.Log.log("SimpleServer", "Failed to accept socket - #{inspect(reason)}", &Utils.NewColors.with_bg_yellow/1)
        accept_connections(socket)
    end
  end

  defp handle_client(client, pid) do
    case read_line(client) do
      {:ok, data} ->
        data
        |> String.trim()
        |> String.downcase()
        |> (fn
              "exit" ->
                Utils.Log.log("SimpleServer", "Close the client - exit", &Utils.NewColors.with_bg_yellow/1)

                send(self(), :stop)
                :ssl.close(client)
                Actors.Bridge.exit(pid)

              no_white_spaces ->
                Actors.Bridge.forward_data(pid, no_white_spaces)
                handle_client(client, pid)
            end).()

      {:error, :closed} ->
        Actors.Bridge.client_disconected(pid)
        Utils.Log.log("SimpleServer", "Client disconnected", &Utils.NewColors.with_bg_yellow/1)

      {:error, reason} ->
        Utils.Log.log("SimpleServer", "Error - #{reason}", &Utils.NewColors.with_bg_yellow/1)
    end

    receive do
      :stop ->
        Utils.Log.log("SimpleServer", "Stopping the handle_client...", &Utils.NewColors.with_bg_yellow/1)
        exit(:normal)

      _ ->
        # Ignore other messages for now
        Utils.Log.log("SimpleServer", "Unknown message received", &Utils.NewColors.with_bg_yellow/1)
    end
  end

  defp read_line(client) do
    case :ssl.recv(client, 0) do
      {:ok, data} ->
        {:ok, data}

      {:error, :closed} ->
        {:error, :closed}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
