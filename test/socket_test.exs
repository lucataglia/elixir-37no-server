defmodule MyApp.SocketTest do
  use ExUnit.Case, async: true

  @port 4000

  setup do
    # Start your application if not already running
    {:ok, _} = Application.ensure_all_started(:elixir_37no_server)
    :ok
  end

  test "actor is spawned and handles messages" do
    # Simulate a TCP connection to localhost:4000
    case :gen_tcp.connect(~c"localhost", @port, [:binary, active: false]) do
      # Send a message through the socket
      {:ok, socket} ->
        :ok = :gen_tcp.send(socket, "Hello, server!\n")

        # Read response from the server
        case :gen_tcp.recv(socket, 0) do
          {:ok, response} ->
            IO.puts("Received response: #{response}")

          {:error, reason} ->
            IO.puts("Failed to receive response: #{inspect(reason)}")
        end

        # Optionally wait for processing (if asynchronous)
        Process.sleep(100)

        # Verify actor behavior (example: checking logs or state)
        # assert_received {:actor_message, "Hello, server!"}

        # Close the socket
        :gen_tcp.close(socket)

      x ->
        IO.puts("TEST FAILED: " <> x)
    end
  end
end
