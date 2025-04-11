defmodule Actors.Bridge do
  use GenServer

  defp init_state(client, recipient_actor) do
    %{
      behavior: :menu,
      client: client,
      recipient_actor: recipient_actor
    }
  end

  def start_link(client) do
    IO.puts("Actor.Login start_link")

    GenServer.start_link(__MODULE__, init_state(client, Actors.Login.start_link(client, self())))
  end

  # FORWARD EVERYTHING TO RECIPIENT
  @impl true
  def handle_cast({:recv, _} = envelop, %{recipient_actor: recipient_actor} = state) do
    GenServer.cast(recipient_actor, envelop)

    {:noreply, state}
  end

  # GOTO GAME - Actor.Player new recipient
  @impl true
  def handle_cast({:goto_game}, %{client: client} = state) do
    # {:game, %{state | recipient_actor: Actors.Player.start_link(client, self())}}
    {:game, %{state | recipient_actor: Actors.Player.start_link(client)}}
  end

  # GOTO MENU - Actor.Login new recipient
  @impl true
  def handle_cast({:goto_game}, %{client: client} = state) do
    {:game, %{state | recipient_actor: Actors.Login.start_link(client, self())}}
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    IO.inspect("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  # *** Public api ***
  def forward_data(pid, data) do
    cond do
      data == "" -> GenServer.cast(pid, {:warning, "Invalid input"})
      data != "" -> GenServer.cast(pid, {:recv, data})
    end
  end

  def stop(pid) do
    GenServer.cast(pid, {:stop})
  end
end
