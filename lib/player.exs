Code.require_file("table-manager.exs")
Code.require_file("constants.exs")

defmodule Player do
  use GenServer

  def start_link(client) do
    IO.puts("Player start_link")

    initial_state = %{client: client, name: "", cards: %{}, behavior: :unnamed}

    GenServer.start_link(__MODULE__, initial_state)
  end

  # STOP
  @impl true
  def handle_cast({:stop}, state) do
    # TODO: inform the table manager
    {:stop, :normal, state}
  end

  # UNNAMED
  @impl true
  def handle_cast({:recv, name}, %{client: client, behavior: :unnamed} = state) do
    :gen_tcp.send(client, Constants.warning("Creating the player..."))
    TableManager.add_player(self(), name)

    new_state = Map.put(%{state | behavior: :login}, :name, name)
    {:noreply, new_state}
  end

  # LOGIN
  @impl true
  def handle_cast({:message, msg}, %{client: client, behavior: :login} = state) do
    :gen_tcp.send(client, msg)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:gotolobby}, %{behavior: :login} = state) do
    {:noreply, %{state | behavior: :lobby}}
  end

  @impl true
  def handle_cast({:recv}, %{client: client, behavior: :login} = state) do
    :gen_tcp.send(client, "Wait for the game to start")

    {:noreply, state}
  end

  # LOBBY
  @impl true
  def handle_cast({:print, game_state}, %{client: c, name: n} = state) do
    :gen_tcp.send(c, Constants.print_table(game_state, n))

    {:noreply, state}
  end

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  # *** Public api ***
  def forward_data(pid, data) do
    GenServer.cast(pid, {:recv, data})
  end

  def stop(pid) do
    GenServer.cast(pid, {:stop})
  end
end
